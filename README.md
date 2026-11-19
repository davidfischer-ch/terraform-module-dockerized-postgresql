# PostgreSQL Terraform Module (Dockerized)

Manage PostgreSQL server.

* Runs in bridge networking mode
* Optionally publishes the port to a host IP and port
* Optionally passes server settings on the command line (`settings`)
* Persists data directory
* Configurable healthcheck (based on `pg_isready`)
* Supports one-time init scripts via `/docker-entrypoint-initdb.d`


## Usage

See [examples/default](examples/default) for a complete working configuration. An extension
loaded at the server's start takes `settings`:
[examples/pg-stat-statements](examples/pg-stat-statements) and
[examples/timescaledb](examples/timescaledb).

```hcl
module "database" {
  source = "git::https://github.com/davidfischer-ch/terraform-module-dockerized-postgresql.git?ref=1.3.5"

  identifier = "my-app-database"
  image_id   = docker_image.postgresql.image_id

  # Networking

  hosts      = { "myserver" = "10.0.0.1" }
  network_id = docker_network.app.id

  # Storage

  data_directory = "/data/my-app/database"

  # Database / Authentication

  name     = "my-app"
  user     = "my-app"
  password = random_password.database.result
}
```


## Data layout

All persistent data lives under `data_directory`:

```
data_directory/
├── data/    # PostgreSQL data files (PGDATA)
├── init/    # One-time init scripts (optional, requires init_scripts = true)
└── backup/  # The backup action's dump, which the restore action reads
    ├── dump-20260101T020000Z/      # The last complete dump, named after its UTC time
    └── dump-20260102T020000Z.tmp/  # A dump being written
```


## Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `identifier` | `string` | required | Unique name for resources (must match `^[a-z]+(-[a-z0-9]+)*$`). |
| `enabled` | `bool` | `true` | Start or stop the container. |
| `wait` | `bool` | `true` | Wait for the container to reach a healthy state after creation. |
| `healthcheck_enabled` | `bool` | `true` | Enable the healthcheck (based on `pg_isready`). |
| `healthcheck_interval` | `string` | `"10s"` | Time between healthcheck attempts. |
| `healthcheck_timeout` | `string` | `"5s"` | Maximum time to wait for a healthcheck to complete. |
| `healthcheck_retries` | `number` | `5` | Consecutive failures before marking unhealthy. |
| `healthcheck_start_period` | `string` | `"1m0s"` | Grace period during startup. |
| `image_id` | `string` | required | [PostgreSQL](https://hub.docker.com/_/postgres/tags) Docker image's ID. |
| `app_uid` | `number` | `999` | UID of the user running the container and owning the data directories. |
| `app_gid` | `number` | `999` | GID of the user running the container and owning the data directories. |
| `privileged` | `bool` | `false` | Run the container in privileged mode. |
| `cap_add` | `set(string)` | `[]` | Linux capabilities to add to the container. |
| `cap_drop` | `set(string)` | `[]` | Linux capabilities to drop from the container. |
| `shm_size` | `number` | `null` | Size of `/dev/shm` in MB (at least 64), the shared memory parallel query workers use. `null` leaves the current size in place; a new container gets the Docker daemon's default (64 MB unless configured). |
| `hosts` | `map(string)` | `{}` | Extra `/etc/hosts` entries for the container. |
| `network_id` | `string` | required | Docker network to attach to. |
| `port` | `number` | `5432` | PostgreSQL port (changing not yet implemented). |
| `publish` | `object({ host_ip = string, host_port = optional(number, 5432) })` | `null` | Publish the port to the host (`host_ip` to bind, `host_port` the external port). `null` keeps it reachable only from other containers on `network_id`. |
| `data_directory` | `string` | required | Host path for persistent volumes. |
| `name` | `string` | required | Database name (must match `^[A-Za-z0-9_][A-Za-z0-9_.-]*$`). |
| `user` | `string` | required | Database user (must match `^[A-Za-z0-9_][A-Za-z0-9_.-]*$`). |
| `password` | `string` | required | Database password (sensitive). |
| `password_timeout` | `number` | `300` | Seconds to wait for the server to accept the password before the apply fails. |
| `max_connections` | `number` | `100` | PostgreSQL `max_connections` (1 to 262143). |
| `init_scripts` | `bool` | `false` | Bind-mount `{data_directory}/init` to `/docker-entrypoint-initdb.d`. |
| `settings` | `map(string)` | `{}` | Server settings, each passed as `-c name=value` (`shared_buffers`, `TimeZone`, `pg_stat_statements.track`…); they override the configuration files. `max_connections` has its own variable; `listen_addresses`, `port` and `unix_socket_directories` are refused. Values must not be null nor hold control characters, and must hold no secret (see [Secrets](#secrets)). |


## Outputs

| Name | Description |
|------|-------------|
| `host` | Container hostname. |
| `port` | PostgreSQL port. |
| `name` | Database name. |
| `user` | Database user. |
| `password` | Database password (sensitive). |


## Secrets

* The values of `settings` are part of the container's command: `docker inspect` and the host's
  process list show them. Keep secrets out of them.
* The password reaches PostgreSQL from the `PG_PASSWORD` environment variable, read by `psql`
  inside the container, and never appears on a command line.
* Its `ALTER USER ... PASSWORD` statement runs in a session with statement logging, error statement
  logging and `pg_stat_statements` tracking off: neither the server log nor `pg_stat_statements`
  records it, whatever `settings` holds.


## Requirements

* Terraform >= 1.17
* [kreuzwerker/docker](https://github.com/kreuzwerker/terraform-provider-docker) >= 4.7.0
    * From 4.x on, a server whose container was created without its healthcheck
      (`healthcheck_enabled = false`) is replaced the first time the healthcheck is enabled.


## Tests

```
terraform init -backend=false
terraform test
```

The tests plan against a mocked Docker provider: they assert the password provisioner's shell
command on its text without running it, and leave out the provider's plan of an existing container
(an `shm_size` set back to `null`). They run on every push, in the GitHub workflow (with the newest
Docker provider and its minimum) and in the GitLab pipeline.

`tests/e2e/run.sh` applies the module against a real Docker daemon, checks the password, runs every
action on real data, then destroys everything. The GitHub workflow and the GitLab pipeline run it
on PostgreSQL and on TimescaleDB, its library loaded through `settings`; locally, as root:

```bash
E2E_IMAGE=postgres:18.1 sh tests/e2e/run.sh
```


## Actions

On-demand operations on the database. Each runs only when invoked, never during an ordinary
`apply`, and leaves nothing in the state:

```bash
terraform apply -invoke='module.database.action.docker_exec.<action>'
```

Replace `module.database` with the module's address.

### Backup

Both work in `{data_directory}/backup`.

| Action | What it does | When |
|--------|--------------|------|
| `backup` | `pg_dump` into `{data_directory}/backup/dump-<UTC time>.tmp`, in directory format and uncompressed, renamed `dump-<UTC time>` once complete; the older dumps and the unfinished ones are removed only then | Before an upgrade or a risky change, or on a schedule |
| `restore` | `pg_restore` of the newest complete dump: its objects dropped and created again with their owners, in one transaction, which leaves the database as it was on failure; TimescaleDB stays in restoring mode meanwhile | To roll the database back to the last dump |

One dump is kept. To bring an older one back, restore it with restic into `{data_directory}/backup`
as the newest `dump-*`, then invoke `restore`.

### Maintenance

| Action | What it does | When |
|--------|--------------|------|
| `analyze` | `vacuumdb --analyze-only`: the planner's statistics of every table | After a restore or a large load |
| `check` | `pg_amcheck`: tables and B-tree indexes checked for corruption, `amcheck` installed where missing | After a crash, a disk error or a host change |
| `reindex` | `reindexdb --concurrently`: every index rebuilt without blocking writes, the system catalogs left out | After deleting a large share of a table's rows |
| `update_extensions` | `ALTER EXTENSION ... UPDATE` for every installed extension, each in a session of its own | After moving to an image carrying newer extensions |

`analyze` and `reindex` run one table after the other: a parallel run lists the tables first, and
fails on the internal tables TimescaleDB drops meanwhile. `update_extensions` opens a session per
extension, since TimescaleDB updates only as the first command of a session.


## References

* https://hub.docker.com/_/postgres
* https://github.com/davidfischer-ch/ansible-role-postgresql
