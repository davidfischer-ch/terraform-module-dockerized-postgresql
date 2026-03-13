output "host" {
  description = "Hostname of the PostgreSQL container."
  value       = docker_container.server.hostname
}

output "port" {
  description = "Port bound by PostgreSQL."
  value       = var.port
}

output "name" {
  description = "Database name."
  value       = var.name
}

output "user" {
  description = "Database user."
  value       = var.user
}

output "password" {
  description = "Database password."
  sensitive   = true
  value       = var.password
}
