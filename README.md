# PostgreSQL Terraform Module (Dockerized)

Manage PostgreSQL server.

## References

* https://hub.docker.com/_/postgres
* https://github.com/davidfischer-ch/ansible-role-postgresql

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
