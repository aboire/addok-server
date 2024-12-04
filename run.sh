#!/bin/bash

# Fonction pour afficher les erreurs et arrêter le script
function error_exit {
  echo "Erreur : $1"
  exit 1
}

REPO_PREFIX=${REPO_PREFIX:-communecter}

# Vérifier que le numéro de département est défini dans l'environnement
if [ -z "$DEPARTEMENT" ]; then
  error_exit "La variable d'environnement DEPARTEMENT n'est pas définie. Définissez-la avant d'exécuter ce script, par exemple : export DEPARTEMENT=974"
fi

echo ">>> Traitement pour le département : $DEPARTEMENT"

# Étape 1 : Lancer le build pour la data du département
echo ">>> Lancement du script de build pour le département $DEPARTEMENT"
DEPARTEMENT=$DEPARTEMENT ./build-data.sh || error_exit "Échec du build pour le département $DEPARTEMENT"

# Étape 2 : Arrêter le service Addok
echo ">>> Arrêt du service Addok"
docker-compose down || error_exit "Échec lors de l'arrêt du service Addok"

# Étape 3 : Supprimer l'ancien répertoire de données
echo ">>> Suppression de ./addok-data/addok.db et ./addok-data/dump.rdb"
sudo rm -f ./addok-data/addok.db || error_exit "Impossible de supprimer ./addok-data/addok.db"
sudo rm -f ./addok-data/dump.rdb || error_exit "Impossible de supprimer ./addok-data/dump.rdb "

# Étape 4 : Vérifier que le fichier bundle existe
if [ ! -f "./dist/prebuilt-bundle.zip" ]; then
  error_exit "Le fichier ./dist/prebuilt-bundle.zip n'existe pas. Assurez-vous que le build a généré ce fichier."
fi
echo ">>> Fichier ./dist/prebuilt-bundle.zip trouvé avec succès"

# Étape 5 : Décompresser le bundle dans ./addok-data
echo ">>> Décompression de ./dist/prebuilt-bundle.zip dans ./addok-data"
unzip -o ./dist/prebuilt-bundle.zip -d ./addok-data || error_exit "Échec lors de la décompression du fichier bundle"

# addok-[DEPARTEMENT]
echo ">>> Création du répertoire ./addok-server-$DEPARTEMENT"
mkdir -p ./addok-server-$DEPARTEMENT || error_exit "Impossible de créer le répertoire ./addok-server-$DEPARTEMENT"

echo ">>> Création du Dockerfile dans /addok-server-$DEPARTEMENT"

cp ./addok-dep-template/Dockerfile ./addok-server-$DEPARTEMENT/Dockerfile

echo ">>> Création du fichier build.sh dans ./addok-server-$DEPARTEMENT"
cp ./addok-dep-template/build.sh ./addok-server-$DEPARTEMENT/build.sh

chmod +x ./addok-server-$DEPARTEMENT/build.sh

cd ./addok-server-$DEPARTEMENT
if [ "$PUSH_IMAGE" = "true" ]; then
  PUSH_IMAGE=true REPO_PREFIX=$REPO_PREFIX DEPARTEMENT=$DEPARTEMENT ./build.sh
else
  REPO_PREFIX=$REPO_PREFIX DEPARTEMENT=$DEPARTEMENT ./build.sh
fi
cd ..

# Étape 6 : Nettoyer les fichiers temporaires
echo ">>> Nettoyage des fichiers temporaires"
rm -Rf ./addok-server-$DEPARTEMENT
rm -Rf ./data
rm -Rf ./dist


# créer le fichier docker-compose-[$DEPARTEMENT].yml
echo ">>> Création du fichier docker-compose-$DEPARTEMENT.yml"
cat <<EOF > ./docker-compose-$DEPARTEMENT.yml
version: '3.9'

services:
  addok-server-$DEPARTEMENT:
    image: $REPO_PREFIX/addok-server-$DEPARTEMENT
    privileged: true
    environment:
      ADDOK_FILTERS: citycode,postcode,type
      ADDOK_CLUSTER_NUM_NODES: 1
    ports:
      - '5000:5000'
EOF


echo ">>> Script terminé avec succès"
