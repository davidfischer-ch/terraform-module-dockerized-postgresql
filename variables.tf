variable "identifier" {
  type        = string
  description = "Identifier (must be unique, used to name resources)."
  validation {
    condition     = regex("^[a-z]+(-[a-z0-9]+)*$", var.identifier) != null
    error_message = "Argument `identifier` must match regex ^[a-z]+(-[a-z0-9]+)*$."
  }
}

variable "enabled" {
  type        = bool
  description = "Toggle the containers (started or stopped)."
}

variable "image_id" {
  type        = string
  description = "PostgreSQL image's ID."
}

variable "data_directory" {
  type        = string
  description = "Where data will be persisted (volumes will be mounted as sub-directories)."
}

# Database

variable "name" {
  type        = string
  description = "Database name"
}

# Authentication

variable "user" {
  type = string
}

variable "password" {
  type      = string
  sensitive = true
}

# Configuration

variable "max_connections" {
  type    = number
  default = 100
  validation {
    condition     = var.max_connections >= 1 && var.max_connections <= 262143
    error_message = "Argument `max_connections` should be between 1 and 262143, see https://postgresqlco.nf/doc/en/param/max_connections/."
  }
}

# Networking

variable "network_id" {
  type        = string
  description = "Attach the containers to given network."
}

variable "port" {
  type    = number
  default = 5432

  validation {
    condition     = var.port == 5432
    error_message = "Having `port` different than 5432 is not yet implemented."
  }
}
