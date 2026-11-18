variable "identifier" {
  type        = string
  description = "Identifier (must be unique, used to name resources)."

  validation {
    condition     = can(regex("^[a-z]+(-[a-z0-9]+)*$", var.identifier))
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
  validation {
    condition     = length(setsubtract(var.cap_add, local.linux_capabilities)) == 0
    error_message = "Each entry in `cap_add` must be a valid Linux capability name."
  }
}

variable "cap_drop" {
  type        = set(string)
  description = "Linux capabilities to drop from the container."
  default     = []
  validation {
    condition     = length(setsubtract(var.cap_drop, local.linux_capabilities)) == 0
    error_message = "Each entry in `cap_drop` must be a valid Linux capability name."
  }
}

variable "shm_size" {
  type        = number
  description = <<EOT
    Size of /dev/shm in MB, the shared memory parallel query workers use. Null leaves the current
    size in place; a new container gets the Docker daemon's default (64 MB unless configured).
  EOT
  default     = null

  validation {
    condition     = var.shm_size == null || try(var.shm_size >= 64, false)
    error_message = "Argument `shm_size` must be null or at least 64 (MB)."
  }
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

variable "publish" {
  type = object({
    host_ip   = string
    host_port = optional(number, 5432)
  })
  description = <<EOT
    Publish the PostgreSQL port to the host: `host_ip` is the interface to bind ("0.0.0.0" for all
    interfaces, "127.0.0.1" for localhost-only), `host_port` the external port (defaults to 5432).
    Leave null to not publish - the database stays reachable only from other containers on
    `network_id`.
  EOT
  default     = null
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

  validation {
    condition     = can(regex("^[A-Za-z0-9_][A-Za-z0-9_.-]*$", var.name))
    error_message = "Argument `name` must match regex ^[A-Za-z0-9_][A-Za-z0-9_.-]*$."
  }
}

# Authentication -----------------------------------------------------------------------------------

variable "user" {
  type        = string
  description = "PostgreSQL database user."

  validation {
    condition     = can(regex("^[A-Za-z0-9_][A-Za-z0-9_.-]*$", var.user))
    error_message = "Argument `user` must match regex ^[A-Za-z0-9_][A-Za-z0-9_.-]*$."
  }
}

variable "password" {
  type        = string
  description = "PostgreSQL database password."
  sensitive   = true
}

variable "password_timeout" {
  type        = number
  description = "Seconds to wait for the server to accept the password before the apply fails."
  default     = 300
  nullable    = false

  validation {
    condition     = var.password_timeout > 0
    error_message = "Argument `password_timeout` must be positive."
  }
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

variable "settings" {
  type        = map(string)
  description = <<EOT
    Server settings passed on the command line, each as `-c name=value`, e.g.
    `{ shared_buffers = "1GB", work_mem = "32MB" }`. They override postgresql.conf and
    postgresql.auto.conf. `max_connections` has its own variable. The values show in
    `docker inspect` and in the host's process list: keep secrets out of them.
  EOT
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([
      for name in keys(var.settings) :
      can(regex("^[A-Za-z_][A-Za-z0-9_]*(\\.[A-Za-z_][A-Za-z0-9_]*)*$", name))
    ])
    error_message = <<EOT
      Each key of `settings` must be a PostgreSQL setting name, as `work_mem` or
      `pg_stat_statements.track`.
    EOT
  }

  validation {
    condition     = !contains([for name in keys(var.settings) : lower(name)], "max_connections")
    error_message = "Set `max_connections` with its own variable, not in `settings`."
  }

  validation {
    condition = length(setintersection(
      [for name in keys(var.settings) : lower(name)],
      ["listen_addresses", "port", "unix_socket_directories"]
    )) == 0
    error_message = <<EOT
      The healthcheck, the password provisioner and the published port rely on the default
      `listen_addresses`, `port` and `unix_socket_directories`: leave them out of `settings`.
    EOT
  }

  validation {
    condition     = alltrue([for value in values(var.settings) : value != null])
    error_message = "Each value of `settings` must be set: leave a setting out rather than null."
  }

  validation {
    condition = alltrue([
      for value in values(var.settings) : !can(regex("[[:cntrl:]]", value))
    ])
    error_message = "Each value of `settings` must hold no control character (a tab, a newline)."
  }
}
