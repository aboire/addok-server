#!/bin/sh
set -e

# prefixe du repo de l'image si ENV REPO_PREFIX est défini ou "communecter" par défaut
REPO_PREFIX=${REPO_PREFIX:-communecter}
DEPARTEMENT=${DEPARTEMENT:-974}

# verifier que  ../addok-data/addok.conf, ../addok-data/addok.db et ../addok-data/dump.rdb  existent
if [ ! -f ../addok-data/addok.conf ] || [ ! -f ../addok-data/addok.db ] || [ ! -f ../addok-data/dump.rdb ]; then
  echo "Les fichiers ../addok-data/addok.conf, ../addok-data/addok.db et ../addok-data/dump.rdb doivent exister"
  exit 1
fi

# suprimer les fichiers addok.conf, addok.db et dump.rdb s'ils existent
if [ -f addok.conf ]; then
  rm addok.conf
fi
if [ -f addok.db ]; then
  rm addok.db
fi
if [ -f dump.rdb ]; then
  rm dump.rdb
fi

# copier ../addok-data/addok.conf, ../addok-data/addok.db et ../addok-data/dump.rdb dans le répertoire courant
cp ../addok-data/addok.conf addok.conf
cp ../addok-data/addok.db addok.db
cp ../addok-data/dump.rdb dump.rdb

# Définir VERSION comme un horodatage (format : YYYYMMDDHHMMSS)
VERSION=$(date +"%Y%m%d%H%M%S")

TAG="latest"

echo "VERSION définie à : $VERSION"

# Construire et taguer l'image
docker build --pull --rm -t $REPO_PREFIX/addok-server-$DEPARTEMENT:$VERSION .
docker tag $REPO_PREFIX/addok-server-$DEPARTEMENT:$VERSION $REPO_PREFIX/addok-server-$DEPARTEMENT:$VERSION
# si PUSH_IMAGE est défini, pousser l'image sur le repo
[ ! -z "$PUSH_IMAGE" ] && docker push $REPO_PREFIX/addok-server-$DEPARTEMENT:$VERSION

# Tag supplémentaire pour la version "latest"
docker tag $REPO_PREFIX/addok-server-$DEPARTEMENT:$VERSION $REPO_PREFIX/addok-server-$DEPARTEMENT:$TAG
[ ! -z "$PUSH_IMAGE" ] && docker push $REPO_PREFIX/addok-server-$DEPARTEMENT:$TAG
