#!/usr/bin/env bash
# Loads the EEA file into a fresh Oracle Database Free container, runs every
# check, and writes the findings to data/results/findings_oracle.csv.
#
# Needs: docker, and the EEA file at data/raw/CLRTAP_NFR19_V26_1_GF.csv
# (download link in docs/SOURCES.md).
#
#   scripts/run_on_data.sh
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/oracle_container.sh

DATA_FILE=data/raw/CLRTAP_NFR19_V26_1_GF.csv
[ -f "$DATA_FILE" ] || { echo "missing $DATA_FILE (see docs/SOURCES.md)"; exit 1; }

# SQL*Plus inside the container writes the results as the container's oracle
# user, so the folder must be writable by it.
mkdir -p data/results
chmod 777 data/results

start_oracle -v "$PWD/data/raw":/data:ro -v "$PWD/data/results":/results

install_project

log "Pointing the database at the data folder"
docker exec -i "$CONTAINER" sqlplus -s -L "$SYS_CONNECT" <<SQL
whenever sqlerror exit failure
create or replace directory eea_data as '/data';
grant read on directory eea_data to $APP_USER;
exit
SQL

log "Loading the file and running the checks"
sqlplus_in_container "$APP_CONNECT" /work scripts/load_and_check.sql

log "Done: data/results/findings_oracle.csv"
