locals {
  container_data_directory = "/var/lib/postgresql/data"

  host_data_directory = "${var.data_directory}/data"
}
