# The module against a real Docker daemon, driven by run.sh.
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.7.0"
    }
  }
}

variable "app_uid" {
  type    = number
  default = 999
}

variable "data_directory" {
  type = string
}

variable "image" {
  type = string
}

variable "name" {
  type = string
}

variable "settings" {
  type    = map(string)
  default = {}
}

resource "docker_image" "postgresql" {
  name         = var.image
  keep_locally = true
}

resource "docker_network" "e2e" {
  name = "postgresql-e2e"
}

module "database" {
  source = "../.."

  identifier     = "postgresql-e2e"
  image_id       = docker_image.postgresql.image_id
  network_id     = docker_network.e2e.id
  app_uid        = var.app_uid
  app_gid        = var.app_uid
  data_directory = var.data_directory
  name           = var.name
  user           = "app"
  password       = "an-e2e-password"
  settings       = var.settings
}
