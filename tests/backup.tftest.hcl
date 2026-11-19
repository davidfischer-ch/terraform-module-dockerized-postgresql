mock_provider "docker" {}

variables {
  identifier     = "my-app-database"
  image_id       = "sha256:0123456789abcdef"
  network_id     = "my-app"
  data_directory = "/data/my-app/database"
  name           = "my-app"
  user           = "my-app"
  password       = "secret"
}

run "backup_directory_is_mounted" {
  command = plan

  assert {
    condition = anytrue([
      for volume in docker_container.server.volumes :
      volume.container_path == "/var/lib/postgresql/backup"
      && volume.host_path == "/data/my-app/database/backup"
      && !volume.read_only
    ])
    error_message = "The backup directory must be mounted, writable."
  }

  assert {
    condition = (
      terraform_data.data_directories.triggers_replace[1] == "/data/my-app/database/backup"
    )
    error_message = "The backup directory must be created with the data directory."
  }
}
