locals {
  container_data_directory = "/var/lib/postgresql/data"

  host_data_directory = "${var.data_directory}/data"
  host_init_directory = "${var.data_directory}/init"

  # Set the password from PG_PASSWORD, read by psql inside the container: it never reaches a
  # command line. One attempt every 5 seconds, until the server accepts it or the time is out.
  password_command = <<-EOT
    if [ "${var.enabled}" != true ]; then
      echo "${var.identifier} is disabled: enable it to set the password of ${var.user}." >&2
      exit 1
    fi
    attempts=${ceil(var.password_timeout / 5)}
    until docker exec -i -e PG_PASSWORD ${var.identifier} \
      psql -v ON_ERROR_STOP=1 -U '${var.user}' -d '${var.name}' <<'SQL'
    \set password `printenv PG_PASSWORD`
    SET log_statement = 'none';
    SET log_min_duration_statement = -1;
    SET log_min_error_statement = panic;
    SET pg_stat_statements.track = 'none';
    ALTER USER "${var.user}" PASSWORD :'password';
    SQL
    do
      attempts=$((attempts - 1))
      if [ "$attempts" -le 0 ]; then
        echo "PostgreSQL in ${var.identifier} did not accept the password of ${var.user}" \
          "within ${var.password_timeout} seconds." >&2
        exit 1
      fi
      sleep 5
    done
  EOT

  linux_capabilities = [
    "ALL",
    "AUDIT_CONTROL",
    "AUDIT_READ",
    "AUDIT_WRITE",
    "BLOCK_SUSPEND",
    "BPF",
    "CHECKPOINT_RESTORE",
    "CHOWN",
    "DAC_OVERRIDE",
    "DAC_READ_SEARCH",
    "FOWNER",
    "FSETID",
    "IPC_LOCK",
    "IPC_OWNER",
    "KILL",
    "LEASE",
    "LINUX_IMMUTABLE",
    "MAC_ADMIN",
    "MAC_OVERRIDE",
    "MKNOD",
    "NET_ADMIN",
    "NET_BIND_SERVICE",
    "NET_BROADCAST",
    "NET_RAW",
    "PERFMON",
    "SETFCAP",
    "SETGID",
    "SETPCAP",
    "SETUID",
    "SYS_ADMIN",
    "SYS_BOOT",
    "SYS_CHROOT",
    "SYS_MODULE",
    "SYS_NICE",
    "SYS_PACCT",
    "SYS_PTRACE",
    "SYS_RAWIO",
    "SYS_RESOURCE",
    "SYS_TIME",
    "SYS_TTY_CONFIG",
    "SYSLOG",
    "WAKE_ALARM"
  ]
}
