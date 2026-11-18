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

run "settings_null_passes_none" {
  command = plan

  variables {
    settings = null
  }

  assert {
    condition     = docker_container.server.command == tolist(["-N", "100"])
    error_message = "A null `settings` must pass no setting."
  }
}

run "settings_null_value_is_refused" {
  command = plan

  variables {
    settings = { jit = null, work_mem = "32MB" }
  }

  expect_failures = [var.settings]
}

run "settings_refuse_port" {
  command = plan

  variables {
    settings = { port = "5433" }
  }

  expect_failures = [var.settings]
}

run "settings_refuse_listen_addresses_in_any_case" {
  command = plan

  variables {
    settings = { Listen_Addresses = "localhost" }
  }

  expect_failures = [var.settings]
}

run "settings_refuse_unix_socket_directories" {
  command = plan

  variables {
    settings = { unix_socket_directories = "/tmp" }
  }

  expect_failures = [var.settings]
}

run "settings_accept_postgresql_spellings" {
  command = plan

  variables {
    settings = { TimeZone = "Europe/Zurich", "myapp.tenant.default" = "x" }
  }

  assert {
    condition = docker_container.server.command == tolist([
      "-N", "100", "-c", "TimeZone=Europe/Zurich", "-c", "myapp.tenant.default=x"
    ])
    error_message = "Mixed-case names and custom names with several dots are setting names."
  }
}

run "settings_refuse_max_connections_in_any_case" {
  command = plan

  variables {
    settings = { Max_Connections = "5" }
  }

  expect_failures = [var.settings]
}

run "settings_refuse_a_tab_in_a_value" {
  command = plan

  variables {
    settings = { work_mem = "x\t'; id #" }
  }

  expect_failures = [var.settings]
}

run "settings_refuse_a_newline_in_a_value" {
  command = plan

  variables {
    settings = { archive_command = "a\nb" }
  }

  expect_failures = [var.settings]
}
