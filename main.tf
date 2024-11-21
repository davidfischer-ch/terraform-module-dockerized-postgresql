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

  # Data owner 999:root
  volumes {
    container_path = local.container_data_directory
    host_path      = local.host_data_directory
    read_only      = false
  }

  provisioner "local-exec" {
    command = <<EOT
      chown 999:root "${local.host_data_directory}"
    EOT
  }
}
