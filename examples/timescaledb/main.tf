# TimescaleDB is loaded at the server's start, then created in the database:
# `CREATE EXTENSION IF NOT EXISTS timescaledb;`
resource "docker_image" "postgresql" {
  name         = "timescale/timescaledb:2.32.0-pg18"
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
  source = "git::https://github.com/davidfischer-ch/terraform-module-dockerized-postgresql.git?ref=1.3.4"

  identifier = "my-app-database"
  image_id   = docker_image.postgresql.image_id

  # Process

  shm_size = 256 # MB, for parallel queries

  # Networking

  network_id = docker_network.app.id

  # Storage

  data_directory = "/data/my-app/database"

  # Database

  name = "my-app"
  user = "my-app"

  # Authentication

  password = random_password.database.result

  # Configuration

  settings = {
    shared_preload_libraries      = "timescaledb"
    "timescaledb.telemetry_level" = "off"
  }
}
