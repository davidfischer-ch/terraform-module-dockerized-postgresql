resource "docker_image" "postgresql" {
  name         = "postgres:15.10"
  keep_locally = true
}

resource "docker_network" "app" {
  name   = "my-app"
  driver = "bridge"
}

resource "random_password" "database" {
  length  = 32
  special = false
}

module "database" {
  source = "git::https://github.com/davidfischer-ch/terraform-module-dockerized-postgresql.git?ref=1.3.0"

  identifier = "my-app-database"
  image_id   = docker_image.postgresql.image_id

  # Networking

  network_id = docker_network.app.id

  # Storage

  data_directory = "/data/my-app/database"

  # Database

  name = "my-app"
  user = "my-app"

  # Authentication

  password = random_password.database.result
}
