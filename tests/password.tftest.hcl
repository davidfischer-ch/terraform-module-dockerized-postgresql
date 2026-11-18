mock_provider "docker" {}

variables {
  identifier     = "my-app-database"
  image_id       = "sha256:0123456789abcdef"
  network_id     = "my-app"
  data_directory = "/data/my-app/database"
  name           = "my-app"
  user           = "my-app"
  password       = "it's-a-secret"
}

run "user_refuses_shell_characters" {
  command = plan

  variables {
    user = "app; touch pwned #"
  }

  expect_failures = [var.user]
}

run "name_refuses_shell_characters" {
  command = plan

  variables {
    name = "app $(id)"
  }

  expect_failures = [var.name]
}
