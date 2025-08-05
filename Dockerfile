FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive
ARG FLEXIBEE_DEB

# instalace zakladnich balicku
RUN apt update && apt install -y wget gnupg locales locales-all supervisor apt-transport-https gpg cron procps
RUN wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN echo "deb http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list

# instalace locales
RUN echo "cs_CZ.UTF-8 UTF-8" >> /etc/locale.gen	&& locale-gen

# JAVA 11 (temurin) repozitar
RUN wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor | tee /etc/apt/trusted.gpg.d/adoptium.gpg > /dev/null
RUN echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list

# instalace PostgreSQL a Java (Temurin) a TCL, TK (Flexibee vyzauje k behu)
RUN apt update 
RUN apt install -y libtcl8.6 libtk-img libtk8.6 logrotate netbase postgresql-13 postgresql-client-13 postgresql-client-common postgresql-common sysstat tcl tcl-tls tcl8.6 tcllib tk tk8.6 ucf xz-utils vim postgresql-pltcl-13 xdg-utils temurin-11-jre

# smazeme systemctl, protoze v image je k nicemu a FlexiBee instalacni skript si podle tohoto souboru mysli, ze pouzivame systemd
RUN rm -rf /usr/bin/systemctl
# Zde zadej nazev instalacniho souboru
COPY $FLEXIBEE_DEB /
RUN dpkg -i  ./$FLEXIBEE_DEB

COPY default-flexibee /etc/default/flexibee
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY postgresql-flexibee.conf /etc/postgresql/13/flexibee/conf.d/postgresql-flexibee.conf
COPY flexibee-server.xml /etc/flexibee/flexibee-server.xml
COPY pg_hba.conf /etc/postgresql/13/flexibee/pg_hba.conf
COPY cron-backup /etc/cron.d/cron-backup
COPY on-stop.sh /
RUN chmod +x /on-stop.sh
# smazeme defaultni PostgreSQL cluster, k nicemu ho nepotrebujeme
RUN rm -rf /etc/postgresql/13/main
RUN apt clean
# instalacni soubor muzeme po uspesne instalaci smazat, aby zbytecne nezabiral misto v image
RUN rm -rf ./$FLEXIBEE_DEB

EXPOSE 5434

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
