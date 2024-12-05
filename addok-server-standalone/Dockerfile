# Étape 1 : Utiliser une image complète pour installer les dépendances
FROM debian:bullseye AS builder

# Installer les dépendances nécessaires
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    cron && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# Copier les binaires de cron
RUN mkdir -p /opt/cron-bin /opt/cron-libs
RUN cp -a /usr/bin/crontab /opt/cron-bin/
RUN ldd /usr/bin/crontab | awk '{ if ($3 ~ /^\//) print $3 }' | xargs -I{} cp -v {} /opt/cron-libs/
RUN cp -a /usr/sbin/cron /opt/cron-bin/
RUN ldd /usr/sbin/cron | awk '{ if ($3 ~ /^\//) print $3 }' | xargs -I{} cp -v {} /opt/cron-libs/

# Étape 2 : Image finale basée sur communecter/addok-server
FROM communecter/addok-server as addok-server

# Copier les outils et leurs dépendances depuis l'étape builder
COPY --from=builder /opt/cron-bin/* /usr/bin/
COPY --from=builder /opt/cron-libs/* /usr/lib/

# Copier les fichiers de configuration
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY cronfile /etc/cron.d/update-data

RUN mkdir -p /var/spool/cron/crontabs

RUN chmod -R 0644 /var/spool/cron && \
    chmod 0755 /var/spool/cron/crontabs

# Appliquer les permissions aux fichiers Cron
RUN chmod 0644 /etc/cron.d/update-data && \
    crontab /etc/cron.d/update-data

# Copier prepare_data_script.sh et le rendre exécutable
COPY prepare_data_script.sh /usr/local/bin/prepare_data_script.sh
RUN chmod +x /usr/local/bin/prepare_data_script.sh

# Dossier des données
RUN mkdir -p /data

ENV TZ=Europe/Paris
# Configurer le lien symbolique pour le timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ENV PRE_INDEXED_DATA_URL=https://adresse.data.gouv.fr/data/ban/adresses/latest/addok/addok-france-bundle.zip

# Copier le script d'entrée
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Configurer Supervisor comme point d'entrée
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
