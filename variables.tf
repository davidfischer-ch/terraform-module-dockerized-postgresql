variable "identifier" {
  type = string
}

variable "enabled" {
  type = bool
}

variable "image_id" {
  type        = string
  description = "PostgreSQL image's ID."
}

variable "data_directory" {
  type = string
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

# Networking

variable "network_id" {
  type = string
}

variable "port" {
  type    = number
  default = 5432

  validation {
    condition     = var.port == 5432
    error_message = "Having `port` different than 5432 is not yet implemented."
  }
}
