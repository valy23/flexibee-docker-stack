# Migrace databáze na novější PostgreSQL

Přechod FlexiBee / ABRA Flexi na novější PostgreSQL, na příkladu **13 → 17**.
Podporováno je 13 až 17. Data se přenášejí přes `pg_dumpall` — výměna image sama
nic nemigruje, novější PostgreSQL starý cluster nenastartuje.

## Než začnete

- Odstávka, Flexi bude celou dobu vypnuté.
- Nová instalace musí startovat na prázdném volume. V `docker-stack.yml` přejmenujte
  `data` → `data-pg17`; starý volume je cesta zpět, nemazat dokud není ověřeno.
- Dump se předá volume `tmp` připojeným do obou kontejnerů jako `/tmp`. Po migraci
  ho odstraňte, Flexi tam odkládá dočasné soubory.

---

## 1. Dump ze staré instalace

Ke staré službě přidejte volume `tmp` a nasaďte znovu. Tohle jako první — kontejner
se přitom vytvoří nový a doinstalovaný klient by se zahodil:

```yaml
    volumes:
      - data:/var/lib
      - log:/var/log
      - tmp:/tmp
```

Flexi zastavit, PostgreSQL nechat běžet — `pg_dumpall` nedělá konzistentní snapshot
přes všechny databáze najednou.

```bash
docker stack deploy -c docker-stack.yml flexibee
docker exec -it <stary-kontejner> bash
/etc/init.d/flexibee stop
pg_lsclusters                             # musi rict 13, online
```

Dump musí vzniknout binárkou cílové verze. `pg_dump` ze 13 neuvozuje `system_user`
(od PG 16 rezervované slovo, sloupec v `csuzivatel`) a import takového dumpu se
rozsype na syntaktické chybě. Klienta doinstalujte v kontejneru, repozitář PGDG
je v obrazu už nastavený:

```bash
apt update && apt install -y postgresql-client-17
```

Dump **plnou cestou**. `/usr/bin/pg_dumpall` je `pg_wrapper` a vybírá binárku podle
verze clusteru, takže přes něj dostanete třináctku:

```bash
su - postgres
/usr/lib/postgresql/17/bin/pg_dumpall -p 5435 | gzip > /tmp/pg13-full.sql.gz
zcat /tmp/pg13-full.sql.gz | grep -m1 'Dumped by'    # musi rict pg_dump version 17.x
```

Když tam je 13, dump je nepoužitelný a nepokračujte.

---

## 2. Build nového obrazu

`PG_VERSION` je výchozí 17:

```bash
docker-compose build
docker-compose push
```

---

## 3. Nasazení a úklid cíle

```yaml
    volumes:
      - data-pg17:/var/lib
      - log:/var/log
      - tmp:/tmp
```

```bash
docker stack deploy -c docker-stack.yml flexibee
docker exec -it <novy-kontejner> bash
pg_lsclusters                             # !!! musi rict 17, jinak dal nepokracujte !!!
/etc/init.d/flexibee stop
```

Flexi si samo založí roli `dba` a databázi `centralServer`. Bez jejich odstranění
import havaruje:

```bash
su - postgres
psql -p 5435 -c 'DROP DATABASE "centralServer";'
psql -p 5435 -c 'DROP ROLE dba;'
```

Databáze musí jít první, `dba` je její vlastník.

---

## 4. Import

```bash
zcat /tmp/pg13-full.sql.gz | psql -p 5435 2>&1 | tee /tmp/import.log
```

Dvě chyby v logu jsou očekávané:

- `role "postgres" already exists` — `pg_dumpall` ji vytváří vždy a zahodit ji nelze.
- `function public.pg_stat_statements_reset(oid, oid, bigint) does not exist` —
  funkce má v PG 17 o parametr víc.

---

## 5. Ověření

### Kontrola logu

```bash
grep '^ERROR:' /tmp/import.log | sort -u
```

Kromě těch dvou očekávaných chyb tam nesmí být nic. Když je:

| Chyba | Znamená |
|---|---|
| `syntax error` | dump z nesprávné verze klienta, krok 1 — vše za tím je poškozené |
| `already exists`, `duplicate key`, `violates ... constraint` | cíl nebyl čistý, krok 3 |

Neopravujte ručně — zahoďte naimportované databáze a role a import zopakujte.

### Data

Seznam databází musí odpovídat zdroji a `csuzivatel` nesmí být prázdná (stále
jako `postgres`):

```bash
psql -p 5435 -Atc "select datname from pg_database where not datistemplate order by 1"
psql -p 5435 -d centralServer -Atc 'select dbnazev from csfirma order by 1'
psql -p 5435 -d centralServer -Atc 'select count(*) from csuzivatel'
```

Statistiky, `pg_dump` je nepřenáší:

```bash
vacuumdb -p 5435 --all --analyze-only -j 4
```

Zbytek jako root:

```bash
exit
grep -E 'user|password' /etc/flexibee/flexibee-server.xml
PGPASSWORD=<heslo> psql -h 127.0.0.1 -p 5435 -U dba -l
/etc/init.d/flexibee start
tail -f /var/log/flexibee.log
```

Čekejte `All companies upgraded` a `Server initialization completed`.

### Úklid

Odeberte `tmp:/tmp` z konfigurace, nasaďte znovu a volume smažte:

```bash
docker stack deploy -c docker-stack.yml flexibee    # uz bez tmp:/tmp
docker volume rm flexibee_tmp                       # ve Swarmu prefix jmena stacku
```

---

## Cesta zpět

Starý volume je nedotčený:

```bash
docker stack rm flexibee
# v docker-stack.yml vratit image na starou verzi a volume na 'data'
docker stack deploy -c docker-stack.yml flexibee
```
