#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

# Vérifier que le numéro de département est défini dans l'environnement
if [ -z "$DEPARTEMENT" ]; then
  echo "Erreur : La variable d'environnement DEPARTEMENT n'est pas définie."
  echo "Définissez-la avant d'exécuter ce script, par exemple :"
  echo "export DEPARTEMENT=974"
  exit 1
fi

echo "> Numéro de département : $DEPARTEMENT"

# Répertoire de travail
WORK_DIR="data"
FILE_NAME="adresses-addok-$DEPARTEMENT.ndjson.gz"
FILE_PATH="$WORK_DIR/$FILE_NAME"

# Créer le répertoire de travail si nécessaire
echo "> Création du répertoire de travail : $WORK_DIR"
mkdir -p $WORK_DIR

# Effacer les données précédentes si elles existent
echo "> Suppression de $FILE_NAME si elle existe"
if [ -f "$FILE_PATH" ]; then
  rm "$FILE_PATH"
  echo "  -> Fichier précédent supprimé."
fi

# Télécharger les données
echo "> Téléchargement des données pour le département $DEPARTEMENT"
wget -P $WORK_DIR "https://adresse.data.gouv.fr/data/ban/adresses/latest/addok/$FILE_NAME"

# Vérifier que le fichier a été téléchargé
if [ ! -f "$FILE_PATH" ]; then
  echo "Erreur : Le fichier $FILE_NAME n'a pas pu être téléchargé."
  exit 1
fi

echo "  -> Téléchargement réussi : $FILE_PATH"

# Exécuter le script de traitement
echo "> Création du répertoire de travail"
mkdir -p dist

echo "> Réinitialisation de l'environnement docker"
docker-compose -f docker-compose-build.yml down --volumes --remove-orphans

echo "> Suppression des anciennes données"
sudo rm -Rf data/addok-data

echo "> Démarrage de Redis"
docker-compose -f docker-compose-build.yml up -d addok-importer-redis

echo "> Importation des données dans Redis"
gunzip -c data/*.ndjson.gz | docker-compose -f docker-compose-build.yml run -T addok-importer batch

echo "> Création des ngrams"
docker-compose -f docker-compose-build.yml run addok-importer ngrams

echo "> Écriture du dump de la base Redis et arrêt de l'instance"
docker-compose -f docker-compose-build.yml run addok-importer-redis-save

echo "> Démontage de l'environnement docker"
docker-compose -f docker-compose-build.yml down --volumes --remove-orphans

echo "> Préparation de l'archive"
zip -j dist/prebuilt-bundle.zip dist/addok.db dist/dump.rdb addok-importer/addok.conf

echo "> Nettoyage"
sudo rm -f dist/addok.db && sudo rm -f dist/dump.rdb

echo "Terminé"

