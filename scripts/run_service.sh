#!/usr/bin/env bash
# Builds the API (service/) and serves it from Tomcat 10.1 in Docker, at
# http://localhost:8080/api/..., over the database scripts/run_on_data.sh
# loaded. Run that first; this script leaves the database as it is.
#
# Needs: docker, java 17 or later, maven.
#
#   scripts/run_service.sh
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/oracle_container.sh
require docker java mvn curl

API_CONTAINER=lrtap-qc-api
TOMCAT_IMAGE="${TOMCAT_IMAGE:-tomcat:10.1-jdk17}"
PORT="${API_PORT:-8080}"

if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" != "true" ]; then
    echo "The database container ($CONTAINER) is not running; start it with scripts/run_on_data.sh" >&2
    exit 1
fi

log "Building the API"
mvn -B -q -f service/pom.xml package

log "Starting Tomcat ($TOMCAT_IMAGE)"
docker rm -f "$API_CONTAINER" >/dev/null 2>&1 || true
# Deployed as ROOT.war, so the API sits at /api rather than under a context path.
docker run -d --name "$API_CONTAINER" --network "$NETWORK" -p "$PORT:8080" \
    -e LRTAP_JDBC_URL="$JDBC_FROM_NETWORK" \
    -e LRTAP_JDBC_USER="$APP_USER" -e LRTAP_JDBC_PASSWORD="$APP_PASSWORD" \
    -v "$PWD/service/target/lrtap-qc-api.war":/usr/local/tomcat/webapps/ROOT.war:ro \
    "$TOMCAT_IMAGE" >/dev/null

log "Waiting for the API"
for _ in $(seq 1 30); do
    if curl -fsS "http://localhost:$PORT/api/runs" >/dev/null 2>&1; then
        cat <<MSG

The API is up. Try:
  curl http://localhost:$PORT/api/runs
  curl http://localhost:$PORT/api/runs/latest/summary
  curl "http://localhost:$PORT/api/runs/latest/findings?check=QC05&country=LV"
  curl "http://localhost:$PORT/api/series?country=DE&pollutant=SOX&sector=NATIONAL%20TOTAL"
MSG
        exit 0
    fi
    sleep 2
done
docker logs "$API_CONTAINER" >&2
echo "The API did not start; Tomcat's log is above." >&2
exit 1
