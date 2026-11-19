#!/usr/bin/env sh

# Apply the module against the local Docker daemon, run every action on real data, check the
# outcomes, then destroy everything. Runs as root: the module creates and chowns its directories.
# Against a Docker-in-Docker daemon, whose filesystem the bind mounts live on, set E2E_APP_UID=0:
# the container then starts as root and PostgreSQL takes ownership of its directory itself.
#
#   E2E_IMAGE=postgres:18.1 sh tests/e2e/run.sh
#   E2E_IMAGE=timescale/timescaledb:2.32.0-pg18 \
#     E2E_SETTINGS='{shared_preload_libraries = "timescaledb"}' sh tests/e2e/run.sh

set -eu

# The data directory: a fresh temporary one, or the one E2E_DATA_DIRECTORY names, absent or empty.
# The cleanup removes only what this run created.
if [ -n "${E2E_DATA_DIRECTORY:-}" ]; then
  DATA_DIRECTORY="${E2E_DATA_DIRECTORY}"
  case "${DATA_DIRECTORY}" in
    /*) ;;
    *)
      echo "FAILED: E2E_DATA_DIRECTORY must be an absolute path" >&2
      exit 1
      ;;
  esac
  if [ -e "${DATA_DIRECTORY}" ] || [ -L "${DATA_DIRECTORY}" ]; then
    if [ -L "${DATA_DIRECTORY}" ] || [ ! -d "${DATA_DIRECTORY}" ] \
      || [ -n "$(ls -A "${DATA_DIRECTORY}")" ]; then
      echo "FAILED: E2E_DATA_DIRECTORY ${DATA_DIRECTORY} is not an empty directory" >&2
      exit 1
    fi
    DATA_DIRECTORY_CREATED=false
  else
    mkdir "${DATA_DIRECTORY}"
    DATA_DIRECTORY_CREATED=true
  fi
else
  DATA_DIRECTORY=$(mktemp -d)
  DATA_DIRECTORY_CREATED=true
fi

cd "$(dirname "$0")"

CONTAINER=postgresql-e2e
# A capital and a dot, which every action must take literally.
DATABASE=e2e.App
APP_UID="${E2E_APP_UID:-999}"
SETTINGS="${E2E_SETTINGS:-}"
[ -n "${SETTINGS}" ] || SETTINGS='{}'

tf() {
  terraform "$@" -input=false -no-color \
    -var "image=${E2E_IMAGE}" -var "settings=${SETTINGS}" -var "app_uid=${APP_UID}" \
    -var "data_directory=${DATA_DIRECTORY}" -var "name=${DATABASE}"
}

invoke() {
  echo "==> action ${1}"
  address="module.database.action.docker_exec.${1}"
  if ! output=$(tf apply -auto-approve "-invoke=${address}" 2>&1); then
    echo "${output}" >&2
    echo "FAILED: action ${1}" >&2
    exit 1
  fi
  echo "${output}" | grep 'exit_code'
}

refused() {
  echo "==> action ${1}, expected to fail"
  address="module.database.action.docker_exec.${1}"
  if tf apply -auto-approve "-invoke=${address}" > /dev/null 2>&1; then
    echo "FAILED: action ${1} succeeded" >&2
    exit 1
  fi
}

# Run a statement in the module's database, or in the one named second.
sql() {
  docker exec "${CONTAINER}" psql -X -v ON_ERROR_STOP=1 -U app -d "${2:-${DATABASE}}" -Atc "$1"
}

# The entries of the backup directory, on one line.
backups() {
  docker exec "${CONTAINER}" ls /var/lib/postgresql/backup | paste -s -d ' ' -
}

# The entries of the backup directory, a lone complete dump's time replaced by <time>.
backups_shape() {
  listing=$(backups)
  case "${listing}" in
    dump-????????T??????Z) echo 'dump-<time>' ;;
    *) echo "${listing}" ;;
  esac
}

expect() {
  if [ "$2" != "$3" ]; then
    echo "FAILED: ${1}: expected ${3}, got ${2}" >&2
    exit 1
  fi
  echo "ok: ${1}"
}

# The bind mounts live on the daemon's filesystem, which is not this one under Docker-in-Docker:
# remove them through the daemon too.
cleanup() {
  tf destroy -auto-approve > /dev/null || true
  docker run --rm --entrypoint rm -v "${DATA_DIRECTORY}:/e2e" "${E2E_IMAGE}" \
    -rf /e2e/backup /e2e/data || true
  [ "${DATA_DIRECTORY_CREATED}" = false ] || rm -rf "${DATA_DIRECTORY}"
}
trap cleanup EXIT

waited=0
until docker info > /dev/null 2>&1; do
  waited=$((waited + 1))
  if [ "${waited}" -ge 300 ]; then
    echo "FAILED: no Docker daemon answered within 300 seconds" >&2
    exit 1
  fi
  sleep 1
done

terraform init -input=false -no-color > /dev/null
tf apply -auto-approve > /dev/null

# Over TCP to the container's own hostname: the local socket and the loopback skip the password.
login() {
  docker exec -e "PGPASSWORD=${1}" "${CONTAINER}" \
    psql -X -h "${CONTAINER}" -U app -d "${DATABASE}" -Atc 'SELECT 1' 2> /dev/null || true
}
expect 'the password set by the module opens a session' "$(login an-e2e-password)" 1
expect 'another password is refused' "$(login not-the-password)" ''

sql 'CREATE TABLE note (id int PRIMARY KEY, body text)'
sql "INSERT INTO note SELECT g, md5(g::text) FROM generate_series(1, 1000) g"

# Objects of a second role, which the restore gives back to it.
sql 'CREATE ROLE tenant'
sql 'CREATE TABLE tenant_note (id int)'
# shellcheck disable=SC2016 # $$ quotes the function body for PostgreSQL.
sql 'CREATE FUNCTION tenant_note_count() RETURNS bigint LANGUAGE sql SECURITY DEFINER
  AS $$SELECT count(*) FROM tenant_note$$'
sql 'ALTER TABLE tenant_note OWNER TO tenant'
sql 'ALTER FUNCTION tenant_note_count() OWNER TO tenant'

# A hypertable of 240 rows in 10 daily chunks, the first 5 compressed.
timescaledb=$(sql "SELECT count(*) FROM pg_extension WHERE extname = 'timescaledb'")
if [ "${timescaledb}" = 1 ]; then
  sql 'CREATE TABLE metric (time timestamptz NOT NULL, value int)'
  sql "SELECT create_hypertable('metric', by_range('time', INTERVAL '1 day'))" > /dev/null
  sql "INSERT INTO metric SELECT t, 1 FROM generate_series(
    '2026-01-01 00:00Z'::timestamptz, '2026-01-10 23:00Z', INTERVAL '1 hour') t"
  sql "ALTER TABLE metric SET (timescaledb.compress)"
  sql "SET client_min_messages = error; SELECT compress_chunk(c)
    FROM show_chunks('metric', older_than => '2026-01-06 00:00Z'::timestamptz) c" > /dev/null
fi

refused restore
echo 'ok: restore fails without a complete dump'
invoke backup
expect 'a backup writes one complete dump' "$(backups_shape)" 'dump-<time>'
last_dump=$(backups)
compressed=$(docker exec "${CONTAINER}" find /var/lib/postgresql/backup -name '*.gz')
expect 'the dump is written uncompressed' "${compressed}" ''
sql 'DELETE FROM note WHERE id > 10'
[ "${timescaledb}" != 1 ] || sql "DELETE FROM metric WHERE time >= '2026-01-03 00:00Z'"
invoke restore
expect 'the restore brings every row back' "$(sql 'SELECT count(*) FROM note')" 1000
expect 'the restore keeps the owner of a table' \
  "$(sql "SELECT tableowner FROM pg_tables WHERE tablename = 'tenant_note'")" tenant
expect 'the restore keeps the owner of a SECURITY DEFINER function' \
  "$(sql "SELECT proowner::regrole FROM pg_proc WHERE proname = 'tenant_note_count'")" tenant
if [ "${timescaledb}" = 1 ]; then
  expect 'the restore brings every row of a hypertable back' \
    "$(sql 'SELECT count(*) FROM metric')" 240
  expect 'the restore keeps the compressed chunks compressed' \
    "$(sql "SELECT count(*) FROM timescaledb_information.chunks
      WHERE hypertable_name = 'metric' AND is_compressed")" 5
  expect 'the restore leaves TimescaleDB out of restoring mode' \
    "$(sql "SELECT current_setting('timescaledb.restoring')")" off
fi

for action in analyze check reindex update_extensions; do
  invoke "${action}"
done
expect 'analyze refreshes the statistics' \
  "$(sql "SELECT last_analyze IS NOT NULL FROM pg_stat_user_tables WHERE relname = 'note'")" t
expect "check works in the module's database" \
  "$(sql "SELECT count(*) FROM pg_extension WHERE extname = 'amcheck'")" 1

sql "ALTER DATABASE \"${DATABASE}\" WITH ALLOW_CONNECTIONS false" postgres
refused update_extensions
echo 'ok: update_extensions fails when it cannot list the extensions'

# A backup failing next to the unfinished dump of an interrupted one.
docker exec "${CONTAINER}" mkdir /var/lib/postgresql/backup/dump-20000101T000000Z.tmp
refused backup
expect 'a failed backup keeps the last complete dump' \
  "$(backups | tr ' ' '\n' | grep -v '[.]tmp$')" "${last_dump}"
sql "ALTER DATABASE \"${DATABASE}\" WITH ALLOW_CONNECTIONS true" postgres
sql 'DELETE FROM note WHERE id > 10'
invoke restore
expect 'the restore reads the newest complete dump, past the unfinished ones' \
  "$(sql 'SELECT count(*) FROM note')" 1000
invoke backup
expect 'a backup removes the older dump and the unfinished ones' "$(backups_shape)" 'dump-<time>'

status=0
tf plan -detailed-exitcode > /dev/null || status=$?
expect 'the actions leave the plan clean' "${status}" 0
