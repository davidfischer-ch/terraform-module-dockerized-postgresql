terraform {
  required_version = ">= 1.17"

  required_providers {
    # https://github.com/kreuzwerker/terraform-provider-docker/tags
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.7.0"
    }

    # https://github.com/hashicorp/terraform-provider-random/tags
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
}
