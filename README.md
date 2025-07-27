## FlexiBee

FlexiBee je účetní software, který vyniká dvěma klíčovými vlastnostmi:
- **Multiplatformnost**: Klient i server lze provozovat na Linuxu i macOS.
- **REST API**: Umožňuje snadnou integraci s dalšími systémy.

## Lze provozovat FlexiBee v Dockeru v produkčním prostředí?

Ano, FlexiBee je možné provozovat v Dockeru v produkčním prostředí, což je ověřeno naší několikaletou praxí ve firmě **UX Fans s.r.o.** (a **Účtio.cz s.r.o.**) bez jakýchkoli problémů. 

Tato konfigurace je navržena pro prostředí **Docker Swarm**, které využíváme na našich serverech, ale je plně kompatibilní i s **Docker Compose**. FlexiBee a databáze **PostgreSQL 13** běží ve stejném kontejneru, což sice není ideální z pohledu dockerové filozofie (jeden proces na kontejner), ale provoz databáze v odděleném kontejneru by vyžadoval úpravy instalačních skriptů FlexiBee. Tyto úpravy by sice byly jednorázově proveditelné, ale komplikovaly by proces pravidelných aktualizací.

---

## Jak na to?

### 1. Stažení aktuální verze FlexiBee

Stáhněte aktuální verzi FlexiBee ve formátu **"Univerzální balíček pro Debian (Ubuntu) Linux"** z oficiálního webu:  
[https://www.flexibee.eu/podpora/stazeni-flexibee/stazeni-ekonomickeho-systemu-flexibee-linux/](https://www.flexibee.eu/podpora/stazeni-flexibee/stazeni-ekonomickeho-systemu-flexibee-linux/)

Uložte soubor do adresáře s konfiguračními soubory.

---

### 2. Konfigurace

Níže je seznam konfiguračních souborů, které budete potřebovat upravit nebo zkontrolovat:

#### Docker konfigurační soubory:
- **`Dockerfile`**: Upravte název staženého instalačního souboru FlexiBee.
- **`Makefile`**: Zjednodušuje build a nasazení, pokud používáte `make`.
- **`cron-backup`**: Denně provádí dump celé databáze a ukládá jej do volume pro snadné zálohování.
- **`default-flexibee`**: Konfigurace pro FlexiBee, která se kopíruje do `/etc/default/flexibee`.
- **`docker-compose.yml`**: Zkontrolujte název a verzi image.
- **`docker-stack.yml`**: Důkladně nastavte **volumes** pro perzistentní ukládání dat. Tato konfigurace je použita v produkci. Flexibee provozujeme na portu 55434. Důležité je i nastavení `locales` na cs_CZ.UTF-8!
- **`flexibee-server.xml`**: Konfigurace kopírovaná do `/etc/flexibee/flexibee-server.xml`.
- **`pg_hba.conf`**: Konfigurace přístupu k PostgreSQL.
- **`postgresql-flexibee.conf`**: Konfigurace PostgreSQL kopírovaná do `/etc/postgresql/13/flexibee/conf.d/postgresql-flexibee.conf`.
- **`supervisord.conf`**: `supervisord` zajišťuje spuštění FlexiBee a `cron` procesu.

---

### 3. Build kontejneru

Spusťte příkaz:  
```bash
docker-compose build
```

---

### 4. Push image do repozitáře

Pro nahrání image do repozitáře použijte:  
```bash
docker-compose push
```

---

### 5. Nasazení kontejneru

Nasazení aplikace pomocí Docker Stack:  
```bash
docker stack deploy -c docker-stack.yml flexibee
```

---

### 6. Ukončení kontejneru

Pro ukončení a odstranění služby (data zůstanou zachována):  
```bash
docker stack rm flexibee
```

---

### 7. Diagnostika

Běží kontejner?
```bash
docker ps -a | grep flexibee
```

Log kontejneru (ten je většinou prázdný, nic se neloguje)
```bash
docker logs idkontejneru
````

Připojení do kontejneru
```bash
docker exec -it idkontejneru bash
```

Flexibee 
```bash
tail -f /var/log/flexibee.log 
```

PostgreSQL
```bash
tail -f /var/log/postgresql/postgresql-13-flexibee.log 
```

---
*Autor: Tomáš Valoušek, UX Fans s.r.o., 17. 1. 2025*
