#!/usr/bin/env bash

# Importer la logique existante pour `prepare_data`
source /usr/local/bin/prepare_data_script.sh

# Fonction : Initialiser le conteneur
initialize() {
    # Vérifier si les données existent déjà
    if data_exists; then
        echo "Data found in /data. Skipping initial data import."
    else
        echo "No data found in /data. Importing initial data..."
        prepare_data
    fi

    # Activer Redis et Node.js dans Supervisor après l'initialisation
    echo "Enabling Redis and Node.js services..."
    supervisorctl start redis-server
    supervisorctl start node-server
}

# Si l'argument "prepare_data" est fourni (appelé par Cron)
if [[ "$1" == "prepare_data" ]]; then
    prepare_data
    exit 0
fi

# Initialiser le conteneur
initialize