terraform {
  required_version = ">= 1.17"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.7.0"
    }
  }
}
