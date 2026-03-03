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
  source = "git::https://github.com/davidfischer-ch/terraform-module-dockerized-postgresql.git?ref=1.1.1"

  identifier     = "my-app-database"
  enabled        = true
  image_id       = docker_image.postgresql.image_id
  data_directory = "/data/my-app/database"

  network_id = docker_network.app.id

  name     = "my-app"
  user     = "my-app"
  password = random_password.database.result

  max_connections = 100
}
