resource "docker_container" "server" {

  image = var.image_id
  name  = var.identifier

  must_run = var.enabled
  start    = var.enabled
  restart  = "always"
  # wait   = true

  # shm_size = 256 # MB

  hostname = var.identifier

  networks_advanced {
    name = var.network_id
  }

  env = [
    "POSTGRES_DB=${var.name}",
    "POSTGRES_USER=${var.user}",
    "POSTGRES_PASSWORD=${var.password}",
    "PGDATA=${local.container_data_directory}"
  ]

  volumes {
    container_path = local.container_data_directory
    host_path      = local.host_data_directory
    read_only      = false
  }
}
