# ChasingSun

ChasingSun is an internal Phoenix LiveView platform for greenhouse operations. It helps farm teams manage ventures, greenhouse crop cycles, harvest capture, farm visits, crop recommendations, forecasts, and performance reporting.

Major areas:

- Public home page and Phoenix-generated account flows
- Authenticated dashboard for operational overview
- Operations portal for greenhouses, harvests, farm visits, recommendations, forecasts, and performance exports
- Admin portal for ventures, crop rules, guest accounts, and the operating guide

## Prerequisites

- Elixir `~> 1.14`
- Erlang/OTP compatible with the installed Elixir version
- PostgreSQL running locally
- Node.js/npm for `assets/package.json` dependencies

No `.tool-versions`, Dockerfile, or `docker-compose.yml` is currently committed.

## Setup

Development database defaults from `config/dev.exs`:

- Host: `localhost`
- Database: `chasing_sun_dev`
- Username: `postgres`
- Password: `postgres`

Install JavaScript dependencies, then bootstrap the app:

```bash
npm install --prefix assets
mix setup
```

`mix setup` runs dependency install, database create/migrate/seed, asset setup, and an initial asset build.

## Run

```bash
mix phx.server
```

Open `http://localhost:4890`.

## Seeded Logins

| Role | Email | Password | Notes |
| --- | --- | --- | --- |
| Admin | `admin@gmail.com` | `123456` | Full management access |
| Guest | `guest@gmail.com` | `123456` | Read-only guest, configurable by admins |

## Common Commands

```bash
mix setup
mix ecto.setup
mix ecto.reset
mix run priv/repo/seeds.exs
mix test
mix format
mix credo
mix assets.build
mix assets.deploy
```

`mix ecto.reset` is destructive because it drops the local database before recreating, migrating, and seeding it. Use it only when resetting local data is intended.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Domains](docs/DOMAINS.md)
- [Portals](docs/PORTALS.md)
- [Authentication and authorization](docs/AUTH.md)
- [Data model](docs/DATA_MODEL.md)
- [Workflows](docs/WORKFLOWS.md)
- [Environment](docs/ENVIRONMENT.md)
