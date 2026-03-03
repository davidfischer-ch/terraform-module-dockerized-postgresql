# PostgreSQL Terraform Module (Dockerized)

Manage PostgreSQL server.

* Runs in bridge networking mode
* Persists data directory
* Configurable healthcheck (based on `pg_isready`)
* Supports one-time init scripts via `/docker-entrypoint-initdb.d`

## Usage

See [examples/default](examples/default) for a complete working configuration.

```hcl
module "database" {
  source = "git::https://github.com/davidfischer-ch/terraform-module-dockerized-postgresql.git?ref=1.1.1"

  identifier     = "my-app-database"
  enabled        = true
  image_id       = docker_image.postgresql.image_id
  data_directory = "/data/my-app/database"

  hosts      = { "myserver" = "10.0.0.1" }
  network_id = docker_network.app.id

  name     = "my-app"
  user     = "my-app"
  password = random_password.database.result

  max_connections = 100
}
```

## Data layout

All persistent data lives under `data_directory`:

```
data_directory/
├── data/  # PostgreSQL data files (PGDATA)
└── init/  # One-time init scripts (optional, requires init_scripts = true)
```

## Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `identifier` | `string` | — | Unique name for resources (must match `^[a-z]+(-[a-z0-9]+)*$`). |
| `enabled` | `bool` | — | Start or stop the container. |
| `wait` | `bool` | `false` | Wait for the container to reach a healthy state after creation. |
| `healthcheck_enabled` | `bool` | `true` | Enable the healthcheck (based on `pg_isready`). |
| `healthcheck_interval` | `string` | `"10s"` | Time between healthcheck attempts. |
| `healthcheck_timeout` | `string` | `"5s"` | Maximum time to wait for a healthcheck to complete. |
| `healthcheck_retries` | `number` | `5` | Consecutive failures before marking unhealthy. |
| `healthcheck_start_period` | `string` | `"1m0s"` | Grace period during startup. |
| `image_id` | `string` | — | [PostgreSQL](https://hub.docker.com/_/postgres/tags) Docker image's ID. |
| `data_directory` | `string` | — | Host path for persistent volumes. |
| `data_owner` | `string` | `"999:root"` | UID:GID for data directories. |
| `name` | `string` | — | Database name. |
| `user` | `string` | — | Database user. |
| `password` | `string` | — | Database password (sensitive). |
| `max_connections` | `number` | `100` | PostgreSQL `max_connections` (1–262143). |
| `init_scripts` | `bool` | `false` | Bind-mount `{data_directory}/init` to `/docker-entrypoint-initdb.d`. |
| `hosts` | `map(string)` | `{}` | Extra `/etc/hosts` entries for the container. |
| `network_id` | `string` | — | Docker network to attach to. |
| `port` | `number` | `5432` | PostgreSQL port (changing not yet implemented). |

## Outputs

| Name | Description |
|------|-------------|
| `host` | Container hostname. |
| `port` | PostgreSQL port. |
| `name` | Database name. |
| `user` | Database user. |
| `password` | Database password (sensitive). |

## Requirements

* Terraform >= 1.6
* [kreuzwerker/docker](https://github.com/kreuzwerker/terraform-provider-docker) >= 3.0.2

## Actions

### Backup database (to a SQL dump)

Note: PGDATA is /var/lib/postgresql/data/

```
CONTAINER=<your-container>
sudo docker exec -it $CONTAINER /bin/bash
root@<your-container>:/# PGPASSWORD=$POSTGRES_PASSWORD pg_dump $POSTGRES_DB --no-owner --no-privileges --clean --format p --file $PGDATA/db.sql --username $POSTGRES_USER
root@<your-container>:/# exit
sudo docker cp $CONTAINER:/var/lib/postgresql/data/db.sql db.sql
sudo docker exec -it $CONTAINER rm /var/lib/postgresql/data/db.sql
```

### Restore database (from a SQL dump)

```
CONTAINER=<your-container>
sudo docker cp db.sql $CONTAINER:/var/lib/postgresql/data/db.sql
sudo docker exec -it $CONTAINER /bin/bash
root@<your-container>:# psql -U $POSTGRES_USER -d $POSTGRES_DB < $PGDATA/db.sql
root@<your-container>:# exit
sudo docker exec -it $CONTAINER rm /var/lib/postgresql/data/db.sql
```

## References

* https://hub.docker.com/_/postgres
* https://github.com/davidfischer-ch/ansible-role-postgresql
