# ChasingSun

ChasingSun is an internal greenhouse operations platform built with Phoenix LiveView. It helps teams manage greenhouse crop cycles, record weekly harvests, review performance, and project the next 8 weeks of output from one system.

## What the app does

- Tracks greenhouses, ventures, and active crop cycles
- Records weekly harvest actuals by greenhouse
- Compares expected yield vs actual yield and estimates revenue
- Projects short-range output and next-Saturday expectations
- Generates crop recommendations and daily operational notifications
- Supports role-based access for admins, operators, viewers, and restricted guests
- Includes AI-assisted pickup-note analysis for harvest entry

## Stack

- Elixir `~> 1.14`
- Phoenix `~> 1.7`
- Phoenix LiveView
- PostgreSQL + Ecto
- Oban for background jobs
- Tailwind CSS
- Esbuild
- Chart.js

## Quick start

### 1. Prerequisites

- Elixir and Erlang installed locally
- PostgreSQL running locally
- Node.js and npm for frontend dependencies such as `chart.js`

### 2. Database defaults

Development uses the following defaults from [config/dev.exs](/Users/michaelmunavu/Documents/projects/chasing_sun/config/dev.exs:1):

- Database: `chasing_sun_dev`
- Username: `postgres`
- Password: `postgres`
- Host: `localhost`

Test uses `chasing_sun_test` with the same local Postgres credentials.

### 3. Install and bootstrap

Install frontend packages:

```bash
npm install --prefix assets
```

Then bootstrap the Phoenix app:

```bash
mix setup
```

`mix setup` runs:

- `mix deps.get`
- `mix ecto.setup`
- asset installation
- initial asset build

### 4. Start the app

```bash
mix phx.server
```

Open `http://localhost:4890`.

## Seeded accounts

The seed script creates these accounts by default:

- Admin: `admin@gmail.com` / `123456`
- Guest: `guest@gmail.com` / `123456`

The admin account can manage ventures, crop rules, guest permissions, greenhouse records, and harvest data. The guest account is read-only and can be limited to specific pages, dashboard sections, and ventures.

## Main screens

- `/dashboard` for live operational overview, status board, charts, and notifications
- `/greenhouses` for greenhouse registry and active crop-cycle management
- `/harvest-records` for weekly harvest capture and pickup-note assisted entry
- `/performance` for expected vs actual yield and revenue review
- `/forecast` for the next 8 weeks of projected output
- `/recommendations` for crop planning recommendations
- `/farm-visits` for farm visit tracking
- `/admin/ventures` for venture management
- `/admin/crop-rules` for crop planning defaults and pricing
- `/admin/guests` for restricted guest accounts
- `/admin/guide` for the in-app operating guide

## AI-assisted pickup-note analysis

Harvest entry supports uploading a pickup-note image and extracting harvest details with OpenAI.

Optional environment variables:

- `OPENAI_API_KEY`
- `CHASING_SUN_OPENAI_MODEL` default: `gpt-4o-mini`

These are read in [config/runtime.exs](/Users/michaelmunavu/Documents/projects/chasing_sun/config/runtime.exs:1).

## Useful commands

```bash
mix phx.server
mix ecto.setup
mix ecto.reset
mix test
mix assets.build
mix assets.deploy
iex -S mix phx.server
```

## Project structure

```text
lib/chasing_sun/
  accounts/        Authentication, roles, and guest restrictions
  analytics/       Forecasting and performance calculations
  harvesting/      Weekly harvest records
  operations/      Greenhouses, ventures, crop cycles, rules, recommendations
  workers/         Oban jobs, including legacy import work

lib/chasing_sun_web/
  live/            LiveView screens
  components/      Shared UI building blocks
  controllers/     Auth and landing-page flows
```

## Background jobs and imports

- Oban is configured with `default` and `imports` queues
- Legacy JSON import support exists through `ChasingSun.Importing`
- Recommendation refreshes and operational updates are handled inside the app layer

## Production configuration

At minimum, production expects:

- `DATABASE_URL`
- `SECRET_KEY_BASE`
- `PHX_HOST`
- `PORT`
- `PHX_SERVER=true`

Optional production settings:

- `POOL_SIZE`
- `ECTO_IPV6`
- `DNS_CLUSTER_QUERY`
- `OPENAI_API_KEY`
- `CHASING_SUN_OPENAI_MODEL`

See [config/runtime.exs](/Users/michaelmunavu/Documents/projects/chasing_sun/config/runtime.exs:1) for the exact runtime configuration.

## Notes for contributors

- The repo currently has app code but no committed `test/` directory yet, so `mix test` is wired in but coverage still needs to be built out.
- There are active product notes in [system_docs.md](/Users/michaelmunavu/Documents/projects/chasing_sun/system_docs.md:1) and [redesign.md](/Users/michaelmunavu/Documents/projects/chasing_sun/redesign.md:1).
- If analytics look wrong, check crop rules, greenhouse cycle dates, and harvest records first. Most downstream screens depend on those inputs.
