# Étape 1 : Utiliser une image complète pour installer les dépendances
FROM debian:bullseye AS builder

# Installer les dépendances nécessaires (Tini, Python, unzip, wget)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    procps \
    netcat \
    tini && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# Copier les binaires nécessaires dans un répertoire temporaire
RUN mkdir -p /opt/tini /opt/netcat/ /opt/netcat-libs/ /opt/procps /opt/procps-libs
RUN cp -a /usr/bin/tini /opt/tini/
RUN cp -a /bin/nc /opt/netcat/
RUN ldd /bin/nc | awk '{ if ($3 ~ /^\//) print $3 }' | xargs -I{} cp -v {} /opt/netcat-libs/
RUN cp -a /usr/bin/pgrep /opt/procps/
RUN ldd /usr/bin/pgrep | awk '{ if ($3 ~ /^\//) print $3 }' | xargs -I{} cp -v {} /opt/procps-libs/

# Étape 2 : Image finale basée sur communecter/addok-server
FROM communecter/addok-server as addok-server

# Copier les outils depuis l'étape builder
COPY --from=builder /opt/tini/* /usr/bin/
COPY --from=builder /opt/netcat/* /usr/bin/
COPY --from=builder /opt/netcat-libs/* /usr/lib/
COPY --from=builder /opt/procps/* /usr/bin/
COPY --from=builder /opt/procps-libs/* /usr/lib/

RUN mkdir -p /data

ENV PRE_INDEXED_DATA_URL=https://adresse.data.gouv.fr/data/ban/adresses/latest/addok/addok-france-bundle.zip
ENV UPDATE_INTERVAL=3600

# Copier le script d'entrée
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Configurer Tini comme point d'entrée
ENTRYPOINT ["/usr/bin/tini", "--"]

# Commande à exécuter
CMD ["/docker-entrypoint.sh"]