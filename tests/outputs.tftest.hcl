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

run "outputs_describe_the_server" {
  command = plan

  assert {
    condition     = output.host == "my-app-database"
    error_message = "`host` must be the container's hostname, its identifier."
  }

  assert {
    condition     = output.port == 5432
    error_message = "`port` must be the PostgreSQL port."
  }

  assert {
    condition     = output.name == "my-app" && output.user == "my-app"
    error_message = "`name` and `user` must be the database and its user."
  }

  assert {
    condition     = nonsensitive(output.password) == "secret"
    error_message = "`password` must be the database password."
  }
}
