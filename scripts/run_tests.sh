#!/usr/bin/env bash
# Runs the full test suite against a fresh Oracle Database Free container.
# Used both locally and in GitHub Actions, so there is one way to run tests.
#
# Needs: docker, java 11+, curl, unzip.
#
#   scripts/run_tests.sh
#
# Steps:
#   1. start a new Oracle Free container with an empty schema "qc"
#   2. install utPLSQL (the test framework) as SYS
#   3. install the project, then the test packages, into "qc"
#   4. run every test with utPLSQL-cli; the exit code is non-zero on failure
set -euo pipefail

cd "$(dirname "$0")/.."

IMAGE="${ORACLE_IMAGE:-gvenzl/oracle-free:23-slim-faststart}"
CONTAINER=lrtap-qc-oracle
SYS_PASSWORD=oracle
APP_USER=qc
APP_PASSWORD=qc
PDB=FREEPDB1
CACHE=.cache

log() { printf '\n== %s\n' "$*"; }

# Runs a SQL script inside the container. $1 = connect string, $2 = working
# directory inside the container, $3 = script path relative to it.
sqlplus_in_container() {
    docker exec -w "$2" "$CONTAINER" sqlplus -s -L "$1" "@$3"
}

log "Downloading utPLSQL and utPLSQL-cli (cached in $CACHE)"
mkdir -p "$CACHE"
if [ ! -d "$CACHE/utPLSQL" ]; then
    curl -sSL -o "$CACHE/utPLSQL.zip" \
        https://github.com/utPLSQL/utPLSQL/releases/latest/download/utPLSQL.zip
    unzip -q "$CACHE/utPLSQL.zip" -d "$CACHE"
fi
if [ ! -d "$CACHE/utPLSQL-cli" ]; then
    curl -sSL -o "$CACHE/utPLSQL-cli.zip" \
        https://github.com/utPLSQL/utPLSQL-cli/releases/latest/download/utPLSQL-cli.zip
    unzip -q "$CACHE/utPLSQL-cli.zip" -d "$CACHE"
fi

log "Starting a fresh Oracle Free container ($IMAGE)"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$CONTAINER" -p 1521:1521 \
    -e ORACLE_PASSWORD="$SYS_PASSWORD" \
    -e APP_USER="$APP_USER" -e APP_USER_PASSWORD="$APP_PASSWORD" \
    -v "$PWD":/work:ro \
    "$IMAGE" >/dev/null

log "Waiting for the database"
for _ in $(seq 1 60); do
    if docker exec "$CONTAINER" healthcheck.sh >/dev/null 2>&1; then
        break
    fi
    sleep 5
done
docker exec "$CONTAINER" healthcheck.sh >/dev/null || { docker logs "$CONTAINER"; exit 1; }

SYS_CONNECT="sys/$SYS_PASSWORD@//localhost:1521/$PDB as sysdba"
APP_CONNECT="$APP_USER/$APP_PASSWORD@//localhost:1521/$PDB"

log "Installing utPLSQL"
sqlplus_in_container "$SYS_CONNECT" /work/$CACHE/utPLSQL/source install_headless.sql

log "Granting privileges to $APP_USER"
sqlplus_in_container "$SYS_CONNECT" /work scripts/grant_app_user.sql

log "Installing the project"
sqlplus_in_container "$APP_CONNECT" /work/db install.sql

log "Installing the tests"
sqlplus_in_container "$APP_CONNECT" /work/tests install.sql

log "Running the tests"
"$CACHE/utPLSQL-cli/bin/utplsql" run "$APP_CONNECT" \
    -f=ut_documentation_reporter -c \
    -f=ut_junit_reporter -o=test-results.xml \
    --failure-exit-code=1
