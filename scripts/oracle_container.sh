# Shared by run_tests.sh and run_on_data.sh: start a fresh Oracle Database
# Free container and run SQL scripts inside it. Source this file; do not run it.

IMAGE="${ORACLE_IMAGE:-gvenzl/oracle-free:23-slim-faststart}"
CONTAINER=lrtap-qc-oracle
SYS_PASSWORD=oracle
APP_USER=qc
APP_PASSWORD=qc
PDB=FREEPDB1
SYS_CONNECT="sys/$SYS_PASSWORD@//localhost:1521/$PDB as sysdba"
APP_CONNECT="$APP_USER/$APP_PASSWORD@//localhost:1521/$PDB"

log() { printf '\n== %s\n' "$*"; }

# Starts a new container with the repository at /work (read-only).
# Any arguments are passed to docker run, e.g. extra -v mounts.
start_oracle() {
    log "Starting a fresh Oracle Free container ($IMAGE)"
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
    docker run -d --name "$CONTAINER" -p 1521:1521 \
        -e ORACLE_PASSWORD="$SYS_PASSWORD" \
        -e APP_USER="$APP_USER" -e APP_USER_PASSWORD="$APP_PASSWORD" \
        -v "$PWD":/work:ro \
        "$@" \
        "$IMAGE" >/dev/null

    log "Waiting for the database"
    for _ in $(seq 1 60); do
        if docker exec "$CONTAINER" healthcheck.sh >/dev/null 2>&1; then
            return 0
        fi
        sleep 5
    done
    docker logs "$CONTAINER"
    return 1
}

# Runs a SQL script inside the container.
#   $1 connect string, $2 working directory in the container, $3 script
sqlplus_in_container() {
    docker exec -w "$2" "$CONTAINER" sqlplus -s -L "$1" "@$3"
}

grant_app_user() {
    log "Granting privileges to $APP_USER"
    sqlplus_in_container "$SYS_CONNECT" /work scripts/grant_app_user.sql
}

install_project() {
    log "Installing the project"
    sqlplus_in_container "$APP_CONNECT" /work/db install.sql
}
