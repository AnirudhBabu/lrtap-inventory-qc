#!/usr/bin/env bash
# Runs the full test suite against a fresh Oracle Database Free container.
# Used both locally and in GitHub Actions, so there is one way to run tests.
#
# Needs: docker, java 17 or later, maven, curl, unzip.
#
# Two suites run against the same database: the utPLSQL tests of the SQL,
# then the JUnit tests of the API in service/, including its tests against
# Oracle.
#
#   scripts/run_tests.sh
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/oracle_container.sh
require docker java mvn curl unzip

CACHE=.cache

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

start_oracle

log "Installing utPLSQL"
# The installer writes temporary files (params.sql.tmp, install.log) next to
# its scripts, and /work is read-only, so run it from a writable copy. If it
# cannot write them it silently skips the public grants and synonyms.
docker exec "$CONTAINER" cp -r "/work/$CACHE/utPLSQL/source" /tmp/utplsql
sqlplus_in_container "$SYS_CONNECT" /tmp/utplsql install_headless.sql

grant_app_user

log "Checking $APP_USER can call utPLSQL"
sqlplus_in_container "$APP_CONNECT" /work scripts/check_utplsql.sql

install_project

log "Installing the tests"
sqlplus_in_container "$APP_CONNECT" /work/tests install.sql

log "Running the utPLSQL tests"
"$CACHE/utPLSQL-cli/bin/utplsql" run "$APP_CONNECT" \
    -f=ut_documentation_reporter -c \
    -f=ut_junit_reporter -o=test-results.xml \
    --failure-exit-code=1

log "Running the API tests (JUnit), including those against Oracle"
LRTAP_JDBC_URL="$JDBC_FROM_HOST" LRTAP_JDBC_USER="$APP_USER" LRTAP_JDBC_PASSWORD="$APP_PASSWORD" \
    mvn -B -f service/pom.xml verify
