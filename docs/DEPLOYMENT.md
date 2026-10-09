# Deployment

One container: Rails serving the React bundle, SQLite on a mounted volume.

## Why one machine

SQLite serialises writes and the application has a single user (ADR 004). A second machine would
not share the volume, so it would not share the data. Scaling out means moving to Postgres, which
is a `database.yml` change and a migration run — no application code depends on SQLite.

`min_machines_running = 1` rather than zero, so the first visitor does not pay a cold start on a
database that has to be woken up.

## Before the first deploy

```sh
fly launch --no-deploy            # claims the app name in fly.toml
fly volumes create salary_data --size 1 --region fra
fly secrets set SECRET_KEY_BASE="$(bin/rails secret)"
fly secrets set BASIC_AUTH_USERNAME=hr BASIC_AUTH_PASSWORD="$(openssl rand -base64 24)"
fly deploy
```

`BASIC_AUTH_PASSWORD` is what activates the guard from ADR 005. Without it the instance is open to
anyone with the URL, which is not acceptable for a dataset that looks like real compensation data —
even though it is synthetic.

A 1 GB volume is generous: the seeded database is roughly 10 MB.

## What happens on boot

`bin/docker-entrypoint` runs `db:prepare`, which creates and migrates the database when the volume
is empty and does nothing afterwards. With `SEED_ON_BOOT=true` it then seeds, but only when there
are no employees, so a redeploy never overwrites data.

## Environment

| Variable | Required | Purpose |
|---|---|---|
| `SECRET_KEY_BASE` | yes | Rails message signing |
| `DATABASE_PATH` | yes in production | Path on the mounted volume |
| `BASIC_AUTH_PASSWORD` | strongly recommended | Activates the Basic auth guard |
| `BASIC_AUTH_USERNAME` | no | Defaults to `hr` |
| `SEED_ON_BOOT` | no | Seeds 10,000 employees when the database is empty |

## Image

Two stages. The builder carries a C toolchain and Node to compile gems and build the Vite bundle;
the runtime image carries neither, only the compiled gems, the application and the built assets.
It runs as an unprivileged user, and `/data` is the only writable path that matters.

## Verified, and not verified

Verified locally:

- the application boots with `RAILS_ENV=production` against a `DATABASE_PATH` on disk
- the production Vite build succeeds
- the Basic auth guard challenges unauthenticated requests and accepts correct credentials, with
  `/up` left reachable so the platform health check still works (7 request specs)

**Not verified:** the Docker image has not been built, and nothing has been deployed. Docker is
installed on the development machine but its daemon is not running, and deploying requires a Fly
account. The Dockerfile and `fly.toml` are written and reviewed but unproven, and should be treated
as such until a build has actually run.
