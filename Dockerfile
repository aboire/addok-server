# Stage 1
FROM nikolaik/python-nodejs:python3.10-nodejs20-bullseye AS build
WORKDIR /app

# Installer les dépendances nécessaires (Tini, Python, unzip, wget, netcat, build-essential, gcc)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    unzip \
    wget && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# Copier les binaires nécessaires dans un répertoire temporaire
RUN mkdir -p /opt/unzip /opt/wget /opt/wget-libs /opt/tini /opt/netcat/ /opt/netcat-libs/
RUN cp -a /usr/bin/unzip /opt/unzip/
RUN ldd /usr/bin/wget | awk '{ if ($3 ~ /^\//) print $3 }' | xargs -I{} cp -v {} /opt/wget-libs/
RUN cp -a /usr/bin/wget /opt/wget/

COPY package.json yarn.lock ./
RUN yarn install --prod --frozen-lockfile

# Désactiver la barre de progression pip
RUN pip config --user set global.progress_bar off

COPY requirements.txt ./
RUN pip install --user -r requirements.txt

# Stage 2
FROM --platform=linux/amd64 redis:7.0 AS redis

# Stage 3
FROM nikolaik/python-nodejs:python3.10-nodejs20-slim
WORKDIR /app

COPY --from=redis /usr/local/bin/redis-server /usr/local/bin/redis-server
COPY --from=redis /usr/local/bin/redis-cli /usr/local/bin/redis-cli
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /root/.local /root/.local

# Copier les outils depuis l'étape builder
COPY --from=build /opt/unzip/* /usr/bin/
COPY --from=build /opt/wget/* /usr/bin/
COPY --from=build /opt/wget-libs/* /usr/lib/

COPY . .

ENV ADDOK_CONFIG_MODULE /data/addok.conf
ENV SQLITE_DB_PATH /data/addok.db
ENV ADDOK_REDIS_DATA_DIR /data

ENV PATH=/root/.local/bin:$PATH

ENV NODE_ENV=production

EXPOSE 5000

CMD ["node", "server.js"]
