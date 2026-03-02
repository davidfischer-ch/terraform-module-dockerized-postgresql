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
      test     = ["CMD-SHELL", "pg_isready -U ${var.user} -d ${var.name}"]
      interval = var.healthcheck_interval
      timeout  = var.healthcheck_timeout
      retries  = var.healthcheck_retries
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

  provisioner "local-exec" {
    command = <<EOT
      mkdir -p "${local.host_data_directory}"
      chown ${var.data_owner} "${local.host_data_directory}"
    EOT
  }
}
