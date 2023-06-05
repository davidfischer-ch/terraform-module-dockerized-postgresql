terraform {
  required_version = ">= 1.3"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 3.0.2"
    }

    jinja = {
      # 18-12-2022 Released 16-12-2022
      source  = "NikolaLohinski/jinja"
      version = ">= 1.4.0"
    }

    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }

    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.1"
    }
  }
}
