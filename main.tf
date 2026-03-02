resource "docker_container" "server" {

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
