#!/usr/bin/env bash

# Fonction : Vérifier si les données existent
data_exists() {
    if [[ -f /data/addok.db && -f /data/addok.conf && -f /data/dump.rdb ]]; then
        return 0  # Les données existent
    else
        return 1  # Les données sont absentes
    fi
}

# Fonction : Désactiver temporairement les services dans Supervisor
disable_supervisor_services() {
    echo "Disabling Redis and Node.js in Supervisor..."
    supervisorctl stop redis-server
    supervisorctl stop node-server
}

# Fonction : Réactiver les services dans Supervisor
enable_supervisor_services() {
    echo "Re-enabling Redis and Node.js in Supervisor..."
    supervisorctl start redis-server
    supervisorctl start node-server
}

# Fonction : Télécharger et préparer les données initiales ou mises à jour
prepare_data() {
    LOCKFILE=/tmp/prepare_data.lock

    # Configurer un trap pour nettoyer les fichiers temporaires et réactiver les services
    trap "
    echo '$(date): Script interrupted or completed. Performing cleanup...'
    rm -f $LOCKFILE /tmp/addok-pre-indexed-data.zip
    rm -rf /tmp/addok-pre-indexed-data
    if data_exists; then
        enable_supervisor_services
    fi
    echo 'Cleanup completed successfully.'
    " EXIT

    if [ -f "$LOCKFILE" ]; then
        echo "Another instance of prepare_data is running. Exiting."
        exit 1
    fi

    # Créer un verrou
    touch "$LOCKFILE"

    echo "Downloading data from $PRE_INDEXED_DATA_URL"
    echo "$(date): Starting wget"
    wget -q --timeout=30 --tries=3 "$PRE_INDEXED_DATA_URL" -O /tmp/addok-pre-indexed-data.zip
    if [[ $? -ne 0 || ! -s /tmp/addok-pre-indexed-data.zip ]]; then
        echo "Error: Failed to download data or file is empty."
        rm -f /tmp/addok-pre-indexed-data.zip
        exit 1
    fi
    echo "$(date): wget completed successfully."

    echo "Extracting downloaded data..."
    unzip -o /tmp/addok-pre-indexed-data.zip -d /tmp/addok-pre-indexed-data

    echo "Verifying required files..."
    for file in addok.conf addok.db dump.rdb; do
        if [[ ! -f "/tmp/addok-pre-indexed-data/$file" ]]; then
            echo "Error: Missing $file in downloaded data." >&2
            rm -rf /tmp/addok-pre-indexed-data /tmp/addok-pre-indexed-data.zip
            exit 1
        fi
    done

    # Si les données existent, arrêter Redis et Node.js pour une mise à jour
    if data_exists; then
        disable_supervisor_services
    fi

    echo "Moving data to /data..."
    mv /tmp/addok-pre-indexed-data/addok.conf /data/addok.conf
    mv /tmp/addok-pre-indexed-data/addok.db /data/addok.db
    mv /tmp/addok-pre-indexed-data/dump.rdb /data/dump.rdb

    echo "Cleaning up temporary files..."
    rm -rf /tmp/addok-pre-indexed-data /tmp/addok-pre-indexed-data.zip

    # Redémarrer les services si nécessaire
    if data_exists; then
        enable_supervisor_services
    fi

    echo "Data preparation complete."
}
