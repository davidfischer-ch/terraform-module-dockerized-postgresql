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

variable "wait" {
  type        = bool
  default     = false
  description = "Wait for the container to reach a healthy state after creation."
}

variable "healthcheck_enabled" {
  type        = bool
  default     = true
  description = "Enable the healthcheck (based on pg_isready)?"
}

variable "healthcheck_interval" {
  type        = string
  default     = "10s"
  description = "Time between healthcheck attempts."
}

variable "healthcheck_timeout" {
  type        = string
  default     = "5s"
  description = "Maximum time to wait for a healthcheck to complete."
}

variable "healthcheck_retries" {
  type        = number
  default     = 5
  description = "Number of consecutive failures before marking unhealthy."
}

variable "image_id" {
  type        = string
  description = "PostgreSQL image's ID."
}

variable "data_directory" {
  type        = string
  description = "Where data will be persisted (volumes will be mounted as sub-directories)."
}

variable "data_owner" {
  type        = string
  default     = "999:root"
  description = "Owner (UID:GID) for data directories."
}

# Database -----------------------------------------------------------------------------------------

variable "name" {
  type        = string
  description = "Database name"
}

# Authentication -----------------------------------------------------------------------------------

variable "user" {
  type = string
}

variable "password" {
  type      = string
  sensitive = true
}

# Configuration ------------------------------------------------------------------------------------

variable "max_connections" {
  type    = number
  default = 100
  validation {
    condition     = var.max_connections >= 1 && var.max_connections <= 262143
    error_message = <<EOT
      Argument `max_connections` should be between 1 and 262143,
      see https://postgresqlco.nf/doc/en/param/max_connections/.
    EOT
  }
}

variable "init_scripts" {
  type        = bool
  default     = false
  description = <<EOT
    Bind-mount {data_directory}/init to /docker-entrypoint-initdb.d (read-only).
    Scripts placed there run once when PostgreSQL initializes a new database.
  EOT
}

# Networking ---------------------------------------------------------------------------------------

variable "hosts" {
  type        = map(string)
  default     = {}
  description = "Add entries to container hosts file."
}

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
