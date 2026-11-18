# Changelog


## Release v1.3.3 (2026-11-18)

Diff: https://github.com/davidfischer-ch/terraform-module-dockerized-postgresql/compare/1.3.2...1.3.3

### Features

Server:

* Add a `settings` variable to pass server settings on the command line, each as `-c name=value`
* Add a `shm_size` variable to size `/dev/shm` for parallel queries

Password:

* Add a `password_timeout` variable bounding how long setting the password is retried

CI:

* Add a GitHub workflow running the format check, validation and tests at every push, with the newest Docker provider and its minimum

Docs:

* Add an example for each extension loaded at the server's start: `pg_stat_statements` and TimescaleDB

### Fix and enhancements

Password:

* Set the password from the container's environment, out of command lines, SQL text and server logs
* Connect to the `name` database when setting the password, not to one named after `user`
* Fail at once when the password changes while the container is disabled, and after `password_timeout` otherwise, instead of retrying for ever
* Refuse a `user` or `name` the shell and SQL would misread

Variables:

* Report a malformed `identifier` with its own validation message

Requirements:

* Require Terraform 1.17

Docs:

* Add the Secrets and Tests sections to the README


## Release v1.3.2 (2026-08-11)

### Features

* Add a `publish` variable to expose the PostgreSQL port on a host IP and port

## Release v1.3.1 (2026-03-21)

### Fix and enhancements

* Replace local-exec provisioners with a terraform_data resource for directory management

## Release v1.3.0 (2026-03-14)

### Minor compatibility breaks

* Remove the `CAP_` prefix from `cap_add` and `cap_drop` values — the module now adds it automatically when calling the Docker provider

### Fix and enhancements

* Add validation of `cap_add` and `cap_drop` against the exhaustive list of Linux capabilities
* Reorder variables to be consistent

## Release v1.2.2 (2026-03-13)

### Fix and enhancements

* Set `enabled` and `wait` defaults to `true`
* Refine variable descriptions, validators, and attribute ordering
* Remove redundant default values from examples and README

## Release v1.2.1 (2026-03-13)

### Features

* Ensure password is updated on change using a SQL `ALTER USER … PASSWORD`, you can now taint password w/o needing to do manual steps for the change to take effect

## Release v1.2.0 (2026-03-13)

### Breaking changes

* Replace `data_owner` by `app_uid`, `app_gid` with the same default values of `999`

### Fix and enhancements

* Add `# Process` section: `app_uid`, `app_gid`, `privileged`, `cap_add`, `cap_drop`
  variables wired into the container via `user`, `privileged`, and a dynamic `capabilities` block
* Add `examples/default/` Terraform example

## Release v1.1.1 (2026-03-02)

### Fix and enhancements

* Change `healthcheck_start_period` default from `60s` to `1m0s` to prevent infinite drift

## Release v1.1.0 (2026-03-02)

### Minor compatibility breaks

* Healthcheck is now enabled by default, existing containers will be updated

### Migrations

* Simply set `healthcheck_enabled` to false to revert to previous behavior

### Features

* Add configurable healthcheck based on `pg_isready`:
    * `healthcheck_enabled` default is true
    * `healthcheck_interval` default is 10s
    * `healthcheck_timeout` default is 5s
    * `healthcheck_retries` default is 5
    * `healthcheck_start_period` default is 60s
* Add precondition ensuring `healthcheck_enabled` is true when `wait` is true

## Release v1.0.3 (2026-03-02)

### Features

* Add `data_owner` variable to parameterize data directory ownership

## Release v1.0.2 (2026-03-01)

### Features

* Add `init_scripts` argument to optionally bind mount init scripts directory

## Release v1.0.1 (2025-08-23)

### Fix and enhancements

* Set network mode to bridge to prevent infinite recreate loop

## Release v1.0.0 (2025-01-20)

Initial release
