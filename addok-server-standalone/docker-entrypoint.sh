#!/usr/bin/env bash

# Variables globales
DEFAULT_UPDATE_URL="https://adresse.data.gouv.fr/data/ban/adresses/latest/addok/addok-france-bundle.zip"
DEFAULT_UPDATE_INTERVAL=86400
PRE_INDEXED_DATA_URL="${PRE_INDEXED_DATA_URL:-$DEFAULT_UPDATE_URL}"
UPDATE_INTERVAL="${UPDATE_INTERVAL:-$DEFAULT_UPDATE_INTERVAL}"
REDIS_PORT="${REDIS_PORT:-6379}"

# Fonction : Gestion des signaux pour arrêter les processus proprement
cleanup() {
    echo "Stopping all processes and cleaning up..."

    # Arrêter Redis proprement avec redis-cli
    # Arrêter Redis proprement
    redis-cli shutdown || echo "Warning: Could not stop Redis."

    # Arrêter Node.js
    node_pid=$(pgrep -f "node /app/server.js")
    if [[ -n "$node_pid" ]]; then
        echo "Stopping Node.js process with PID $node_pid..."
        if kill "$node_pid" 2>/dev/null; then
            echo "Node.js stopped successfully."
        else
            echo "Warning: Failed to stop Node.js process with PID $node_pid."
        fi
    else
        echo "Node.js process not found. Skipping."
    fi

    echo "Cleanup complete. Exiting..."
    exit 0
}

# Fonction : Vérifier si les données existent
data_exists() {
    if [[ -f /data/addok.db && -f /data/addok.conf && -f /data/dump.rdb ]]; then
        return 0  # Les données existent
    else
        return 1  # Les données sont absentes
    fi
}

# Fonction : Télécharger et préparer les données
prepare_data() {
    # Variable pour suivre si les données existaient déjà
    local data_was_present=false

    if data_exists; then
        data_was_present=true
    fi

    echo "Downloading data from $PRE_INDEXED_DATA_URL"
    wget -q "$PRE_INDEXED_DATA_URL" -O /tmp/addok-pre-indexed-data.zip

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

    if [[ "$data_was_present" == true ]]; then
        echo "Stopping Redis and Node.js for update..."
        redis-cli shutdown || echo "Warning: Could not stop Redis."
        node_pid=$(pgrep -f "node /app/server.js")
        if [[ -n "$node_pid" ]]; then
            kill "$node_pid" || echo "Warning: Could not stop Node.js."
        fi
    fi

    echo "Updating data directory..."
    mv /tmp/addok-pre-indexed-data/addok.conf /data/addok.conf
    mv /tmp/addok-pre-indexed-data/addok.db /data/addok.db
    mv /tmp/addok-pre-indexed-data/dump.rdb /data/dump.rdb

    echo "Cleaning up temporary files..."
    rm -rf /tmp/addok-pre-indexed-data /tmp/addok-pre-indexed-data.zip

    if [[ "$data_was_present" == true ]]; then
        echo "Restarting Redis..."
        redis-server &
        echo "Waiting for Redis..."
        wait_for_redis
        echo "Restarting Node.js..."
        node /app/server.js &
    fi
}

# Fonction : Attendre que Redis soit prêt
wait_for_redis() {
    echo "Waiting for Redis to be ready..."
    until nc -z localhost "$REDIS_PORT"; do
        sleep 1
    done
    echo "Redis is ready."
}

# Fonction : Boucle de mise à jour
start_updater() {
    while true; do
        sleep "$UPDATE_INTERVAL"
        prepare_data
    done
}

# Initialisation
trap "cleanup" SIGTERM SIGINT
if ! data_exists; then
    echo "No data found. Importing initial data..."
    prepare_data
fi

echo "Starting Redis..."
redis-server &
wait_for_redis

echo "Starting Node.js..."
node /app/server.js &

echo "Starting update loop in the background..."
start_updater &

# Maintenir le conteneur en exécution
tail -f /dev/null
