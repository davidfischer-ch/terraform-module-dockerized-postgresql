resource "docker_container" "server" {

  lifecycle {
    precondition {
      condition     = !var.wait || var.healthcheck_enabled
      error_message = "Argument `healthcheck_enabled` must be true when `wait` is true."
    }
  }

  image = var.image_id
  name  = var.identifier

  command = ["-N", tostring(var.max_connections)]

  must_run = var.enabled
  start    = var.enabled
  restart  = "always"
  wait     = var.wait

  privileged = var.privileged

  dynamic "capabilities" {
    for_each = length(var.cap_add) + length(var.cap_drop) > 0 ? [1] : []
    content {
      add  = [for cap in var.cap_add : "CAP_${cap}"]
      drop = [for cap in var.cap_drop : "CAP_${cap}"]
    }
  }

  user = "${var.app_uid}:${var.app_gid}"

  # shm_size = 256 # MB

  env = [
    "POSTGRES_DB=${var.name}",
    "POSTGRES_USER=${var.user}",
    "POSTGRES_PASSWORD=${var.password}",
    "PGDATA=${local.container_data_directory}"
  ]

  dynamic "healthcheck" {
    for_each = var.healthcheck_enabled ? [1] : []
    content {
      test         = ["CMD-SHELL", "pg_isready -U ${var.user} -d ${var.name}"]
      interval     = var.healthcheck_interval
      timeout      = var.healthcheck_timeout
      retries      = var.healthcheck_retries
      start_period = var.healthcheck_start_period
    }
  }

  dynamic "host" {
    for_each = var.hosts
    content {
      host = host.key
      ip   = host.value
    }
  }

  hostname = var.identifier

  networks_advanced {
    name = var.network_id
  }

  network_mode = "bridge"

  volumes {
    container_path = local.container_data_directory
    host_path      = local.host_data_directory
    read_only      = false
  }

  # Init scripts (read-only, runs only on first init)
  dynamic "volumes" {
    for_each = var.init_scripts ? [local.host_init_directory] : []
    content {
      container_path = "/docker-entrypoint-initdb.d"
      host_path      = volumes.value
      read_only      = true
    }
  }

  depends_on = [terraform_data.data_directories]
}

resource "terraform_data" "password" {
  triggers_replace = [var.password]

  provisioner "local-exec" {
    command = "until docker exec ${var.identifier} psql -U ${var.user} -c \"ALTER USER \\\"${var.user}\\\" PASSWORD '$PG_PASSWORD'\"; do sleep 5; done"
    environment = {
      PG_PASSWORD = var.password
    }
  }

  depends_on = [docker_container.server]
}
