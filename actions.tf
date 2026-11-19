# On-demand operations on the database, run with `terraform apply -invoke=<action address>`.

# Backup -------------------------------------------------------------------------------------------

# Dump the database into {data_directory}/backup/dump-<UTC time>, in directory format, written
# under a .tmp name and renamed once complete. The older dumps are removed only then, and the
# unfinished ones of other runs after them: the newest complete dump is always kept.
action "docker_exec" "backup" {
  config {
    container = docker_container.server.name
    user      = "${var.app_uid}:${var.app_gid}"
    command = ["sh", "-c", <<-EOT
      set -eu
      cd '${local.container_backup_directory}'
      dump="dump-$(date -u +%Y%m%dT%H%M%SZ)"
      mkdir "$dump.tmp"
      pg_dump --format=directory --jobs=2 --compress=0 \
        --username='${var.user}' --file="$dump.tmp" '${var.name}'
      mv "$dump.tmp" "$dump"
      for older in dump-*; do
        case "$older" in
          "$dump") break ;;
          *.tmp) ;;
          *) rm -rf "$older" ;;
        esac
      done
      rm -rf dump-*.tmp
    EOT
    ]
  }
}

# Restore the newest complete dump of {data_directory}/backup into the database, its objects
# dropped and created again. TimescaleDB is in restoring mode for the duration, and leaves it
# whatever the outcome.
action "docker_exec" "restore" {
  config {
    container = docker_container.server.name
    user      = "${var.app_uid}:${var.app_gid}"
    command = ["sh", "-c", <<-EOT
      set -eu
      cd '${local.container_backup_directory}'
      dump=
      for complete in dump-*; do
        case "$complete" in
          *.tmp) ;;
          *) [ ! -d "$complete" ] || dump=$complete ;;
        esac
      done
      if [ -z "$dump" ]; then
        echo 'No complete dump-* in ${local.container_backup_directory} to restore.' >&2
        exit 1
      fi
      query() {
        psql -X -At -v ON_ERROR_STOP=1 --username='${var.user}' --dbname='${var.name}' -c "$1"
      }
      timescaledb=$(query "SELECT count(*) FROM pg_extension WHERE extname = 'timescaledb'")
      [ "$timescaledb" = 0 ] || query 'SELECT timescaledb_pre_restore()' > /dev/null
      status=0
      pg_restore --clean --if-exists --single-transaction \
        --username='${var.user}' --dbname='${var.name}' "$dump" || status=$?
      [ "$timescaledb" = 0 ] || query 'SELECT timescaledb_post_restore()' > /dev/null
      exit "$status"
    EOT
    ]
  }
}

# Maintenance --------------------------------------------------------------------------------------

# Refresh the planner's statistics of every table, one table after the other (README, Maintenance).
action "docker_exec" "analyze" {
  config {
    container = docker_container.server.name
    user      = "${var.app_uid}:${var.app_gid}"
    command = [
      "vacuumdb", "--analyze-only", "--username=${var.user}", "--dbname=${var.name}"
    ]
  }
}

# Check the tables and their B-tree indexes for corruption, installing `amcheck` where missing.
action "docker_exec" "check" {
  config {
    container = docker_container.server.name
    user      = "${var.app_uid}:${var.app_gid}"
    command = [
      "pg_amcheck", "--install-missing", "--username=${var.user}", var.name
    ]
  }
}

# Rebuild every index without blocking writes, in one REINDEX DATABASE (README, Maintenance).
action "docker_exec" "reindex" {
  config {
    container = docker_container.server.name
    user      = "${var.app_uid}:${var.app_gid}"
    command = [
      "reindexdb", "--concurrently", "--username=${var.user}", "--dbname=${var.name}"
    ]
  }
}

# Update every installed extension to the version the image carries, each in a session of its own
# (README, Maintenance).
action "docker_exec" "update_extensions" {
  config {
    container = docker_container.server.name
    user      = "${var.app_uid}:${var.app_gid}"
    command = ["sh", "-c", <<-EOT
      set -eu
      extensions=$(psql -X -At -v ON_ERROR_STOP=1 --username='${var.user}' --dbname='${var.name}' \
        -c 'SELECT extname FROM pg_extension ORDER BY extname')
      for extension in $extensions; do
        psql -X -v ON_ERROR_STOP=1 --username='${var.user}' --dbname='${var.name}' \
          -c "ALTER EXTENSION \"$extension\" UPDATE"
      done
    EOT
    ]
  }
}
