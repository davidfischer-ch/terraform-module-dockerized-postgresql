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

run "identifier_refuses_capitals" {
  command = plan

  variables {
    identifier = "My-App"
  }

  expect_failures = [var.identifier]
}

run "max_connections_refuses_zero" {
  command = plan

  variables {
    max_connections = 0
  }

  expect_failures = [var.max_connections]
}

run "shm_size_refuses_less_than_docker_default" {
  command = plan

  variables {
    shm_size = 32
  }

  expect_failures = [var.shm_size]
}

run "cap_add_refuses_an_unknown_capability" {
  command = plan

  variables {
    cap_add = ["NOT_A_CAPABILITY"]
  }

  expect_failures = [var.cap_add]
}

run "wait_requires_the_healthcheck" {
  command = plan

  variables {
    healthcheck_enabled = false
  }

  expect_failures = [docker_container.server]
}

run "container_runs_as_the_app_user_with_its_database" {
  command = plan

  assert {
    condition     = docker_container.server.user == "999:999"
    error_message = "The container must run as app_uid:app_gid."
  }

  assert {
    condition = alltrue([
      for entry in [
        "POSTGRES_DB=my-app", "POSTGRES_USER=my-app", "PGDATA=/var/lib/postgresql/data"
      ] :
      contains(docker_container.server.env, entry)
    ])
    error_message = "The environment must name the database, its user and the data directory."
  }

  assert {
    condition = anytrue([
      for volume in docker_container.server.volumes :
      volume.container_path == "/var/lib/postgresql/data"
      && volume.host_path == "/data/my-app/database/data"
      && !volume.read_only
    ])
    error_message = "The data directory must be mounted, writable."
  }
}

run "healthcheck_runs_pg_isready_on_the_database" {
  command = plan

  assert {
    condition = (
      docker_container.server.healthcheck[0].test
      == tolist(["CMD-SHELL", "pg_isready -U my-app -d my-app"])
    )
    error_message = "The healthcheck must run pg_isready on the module's database and user."
  }
}

run "healthcheck_is_left_out_when_disabled" {
  command = plan

  variables {
    healthcheck_enabled = false
    wait                = false
  }

  assert {
    condition     = length(docker_container.server.healthcheck) == 0
    error_message = "A disabled healthcheck must leave no healthcheck block."
  }
}

run "port_is_not_published_by_default" {
  command = plan

  assert {
    condition     = length(docker_container.server.ports) == 0
    error_message = "The port must stay unpublished unless `publish` is set."
  }
}

run "port_is_published_on_the_given_address" {
  command = plan

  variables {
    publish = { host_ip = "127.0.0.1", host_port = 5433 }
  }

  assert {
    condition = (
      docker_container.server.ports[0].internal == 5432
      && docker_container.server.ports[0].external == 5433
      && docker_container.server.ports[0].ip == "127.0.0.1"
    )
    error_message = "The port must be published on host_ip:host_port."
  }
}

run "init_scripts_are_mounted_read_only_when_enabled" {
  command = plan

  variables {
    init_scripts = true
  }

  assert {
    condition = anytrue([
      for volume in docker_container.server.volumes :
      volume.container_path == "/docker-entrypoint-initdb.d"
      && volume.host_path == "/data/my-app/database/init"
      && volume.read_only
    ])
    error_message = "The init scripts must be mounted read-only when enabled."
  }
}

run "init_scripts_are_not_mounted_by_default" {
  command = plan

  assert {
    condition = !anytrue([
      for volume in docker_container.server.volumes :
      volume.container_path == "/docker-entrypoint-initdb.d"
    ])
    error_message = "No init scripts may be mounted unless enabled."
  }
}

run "capabilities_carry_the_cap_prefix" {
  command = plan

  variables {
    cap_add  = ["NET_ADMIN"]
    cap_drop = ["MKNOD"]
  }

  assert {
    condition = anytrue([
      for capabilities in docker_container.server.capabilities :
      contains(capabilities.add, "CAP_NET_ADMIN") && contains(capabilities.drop, "CAP_MKNOD")
    ])
    error_message = "Capabilities must reach Docker with their CAP_ prefix."
  }
}

run "all_capabilities_keep_dockers_wildcard" {
  command = plan

  variables {
    cap_add  = ["NET_BIND_SERVICE"]
    cap_drop = ["ALL"]
  }

  assert {
    condition = anytrue([
      for capabilities in docker_container.server.capabilities :
      toset(capabilities.drop) == toset(["ALL"])
      && toset(capabilities.add) == toset(["CAP_NET_BIND_SERVICE"])
    ])
    error_message = "ALL must reach Docker as its wildcard, the other capabilities with CAP_."
  }
}

run "capabilities_are_left_out_by_default" {
  command = plan

  assert {
    condition     = length(docker_container.server.capabilities) == 0
    error_message = "No capabilities block may be set unless one is added or dropped."
  }
}
