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
  default     = true
}

variable "wait" {
  type        = bool
  description = "Wait for the container to reach a healthy state after creation."
  default     = true
}

variable "healthcheck_enabled" {
  type        = bool
  description = "Enable the healthcheck (based on pg_isready)?"
  default     = true
}

variable "healthcheck_interval" {
  type        = string
  description = "Time between healthcheck attempts."
  default     = "10s"
}

variable "healthcheck_timeout" {
  type        = string
  description = "Maximum time to wait for a healthcheck to complete."
  default     = "5s"
}

variable "healthcheck_retries" {
  type        = number
  description = "Number of consecutive failures before marking unhealthy."
  default     = 5

  validation {
    condition     = var.healthcheck_retries >= 1
    error_message = "Argument `healthcheck_retries` must be at least 1."
  }
}

variable "healthcheck_start_period" {
  type        = string
  description = "Grace period during startup where healthcheck failures are not counted."
  default     = "1m0s"
}

variable "image_id" {
  type        = string
  description = "PostgreSQL image's ID."
}

# Process ------------------------------------------------------------------------------------------

variable "app_uid" {
  type        = number
  description = "UID of the user running the container and owning the data directories."
  default     = 999
}

variable "app_gid" {
  type        = number
  description = "GID of the user running the container and owning the data directories."
  default     = 999
}

variable "privileged" {
  type        = bool
  description = "Run the container in privileged mode."
  default     = false
}

variable "cap_add" {
  type        = set(string)
  description = "Linux capabilities to add to the container."
  default     = []
}

variable "cap_drop" {
  type        = set(string)
  description = "Linux capabilities to drop from the container."
  default     = []
}

# Networking ---------------------------------------------------------------------------------------

variable "hosts" {
  type        = map(string)
  description = "Add entries to container hosts file."
  default     = {}
}

variable "network_id" {
  type        = string
  description = "Attach the containers to given network."
}

variable "port" {
  type        = number
  description = "Bind the PostgreSQL port."
  default     = 5432

  validation {
    condition     = var.port == 5432
    error_message = "Having `port` different than 5432 is not yet implemented."
  }
}

# Storage ------------------------------------------------------------------------------------------

variable "data_directory" {
  type        = string
  description = "Where data will be persisted (volumes will be mounted as sub-directories)."
}

# Database -----------------------------------------------------------------------------------------

variable "name" {
  type        = string
  description = "Database name"
}

# Authentication -----------------------------------------------------------------------------------

variable "user" {
  type        = string
  description = "PostgreSQL database user."
}

variable "password" {
  type        = string
  description = "PostgreSQL database password."
  sensitive   = true
}

# Configuration ------------------------------------------------------------------------------------

variable "max_connections" {
  type        = number
  description = "Maximum number of PostgreSQL connections."
  default     = 100

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
  description = <<EOT
    Bind-mount {data_directory}/init to /docker-entrypoint-initdb.d (read-only).
    Scripts placed there run once when PostgreSQL initializes a new database.
  EOT
  default     = false
}
