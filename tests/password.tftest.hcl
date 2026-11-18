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

run "password_connects_to_the_database" {
  command = plan

  variables {
    name = "app"
    user = "admin"
  }

  assert {
    condition     = strcontains(local.password_command, "-d 'app'")
    error_message = "psql must connect to the database `name`, not to one named after `user`."
  }
}

run "password_is_quoted_by_psql_as_a_sql_literal" {
  command = plan

  assert {
    condition     = can(regex("PASSWORD :'[a-z_]+'", local.password_command))
    error_message = "The password must reach the SQL through a psql variable quoted as a literal."
  }
}

run "user_is_quoted_in_the_shell" {
  command = plan

  assert {
    condition     = strcontains(local.password_command, "-U 'my-app'")
    error_message = "The user must reach the shell as one quoted word."
  }
}

run "password_stays_out_of_the_command_line" {
  command = plan

  assert {
    condition     = !strcontains(local.password_command, "$PG_PASSWORD")
    error_message = "The shell must not expand the password into the arguments of a process."
  }
}

run "password_statement_is_neither_logged_nor_tracked" {
  command = plan

  assert {
    condition = alltrue([
      for statement in [
        "SET log_statement = 'none';",
        "SET log_min_duration_statement = -1;",
        "SET log_min_error_statement = panic;",
        "SET pg_stat_statements.track = 'none';",
      ] :
      strcontains(local.password_command, statement)
    ])
    error_message = "Statement logging and pg_stat_statements must be off in the password session."
  }

  assert {
    condition = can(regex(
      "(?s)SET pg_stat_statements.track = 'none';\\n.*ALTER USER", local.password_command
    ))
    error_message = "The logging and tracking settings must come before the password is set."
  }
}
