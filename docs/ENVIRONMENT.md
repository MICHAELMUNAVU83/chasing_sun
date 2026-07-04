# Environment

## Development

Development config is in `config/dev.exs`.

| Setting | Value | Required | Notes |
| --- | --- | --- | --- |
| Database username | `postgres` | Yes | Local PostgreSQL user |
| Database password | `postgres` | Yes | Local PostgreSQL password |
| Database host | `localhost` | Yes | Local PostgreSQL host |
| Database name | `chasing_sun_dev` | Yes | Created by `mix ecto.setup` |
| HTTP port | `4890` | Yes | App URL is `http://localhost:4890` |
| `dev_routes` | `true` | No | Enables LiveDashboard and mailbox preview |

Development uses local Swoosh mail storage and disables the Swoosh API client.

## Test

`config/test.exs` uses `chasing_sun_test#{System.get_env("MIX_TEST_PARTITION")}` with the local PostgreSQL credentials.

## Runtime / Production

Defined in `config/runtime.exs`.

| Variable | Required | Default | Purpose |
| --- | --- | --- | --- |
| `PHX_SERVER` | Optional | unset | Enables the endpoint server when running a release |
| `OPENAI_API_KEY` | Optional | unset | Intended for pickup-note extraction |
| `CHASING_SUN_OPENAI_MODEL` | Optional | `gpt-4o-mini` | OpenAI model setting |
| `DATABASE_URL` | Production required | none | PostgreSQL connection URL |
| `ECTO_IPV6` | Optional | false | Enables IPv6 socket options when `true` or `1` |
| `POOL_SIZE` | Optional | `10` | Repo connection pool size |
| `SECRET_KEY_BASE` | Production required | none | Phoenix cookie/session signing secret |
| `PHX_HOST` | Optional | `example.com` | Production URL host |
| `PORT` | Optional | `4000` | Production HTTP port |
| `DNS_CLUSTER_QUERY` | Optional | unset | DNS cluster discovery query |

TODO: `ChasingSun.OpenAI.api_key/0` is commented out in `lib/chasing_sun/openai.ex`, so `OPENAI_API_KEY` is configured but not currently consumed by that function.

## Assets

The app uses Phoenix's default Tailwind and esbuild setup:

- Tailwind version `3.4.3`
- esbuild version `0.17.11`
- npm dependencies in `assets/package.json`

Mix aliases:

- `assets.setup`: installs Tailwind and esbuild if missing.
- `assets.build`: builds Tailwind and esbuild assets.
- `assets.deploy`: minifies assets and runs `phx.digest`.

## Mix Aliases

- `mix setup`: gets deps, runs `ecto.setup`, installs assets, builds assets.
- `mix ecto.setup`: creates database, migrates, and runs `priv/repo/seeds.exs`.
- `mix ecto.reset`: drops database, then runs `ecto.setup`. This is destructive.
- `mix test`: creates and migrates the test database, then runs tests.
