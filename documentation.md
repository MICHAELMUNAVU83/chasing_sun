# Task Brief for Codex

This file tells you ( Codex ) what to do in this Phoenix project. Work through the
two tasks below **in order**. Inspect the real codebase first — do not assume or
invent details. Where this brief gives example values (app name, schemas), they
are placeholders; replace them with what you actually find in the repo.

---

## Context

This is a [Phoenix](https://www.phoenixframework.org/) (Elixir) project. The
following are missing or out of date and you will produce them:

1. A `README.md` that gets a brand-new developer from clone → running server,
   **and** a comprehensive set of docs that actually explain the system — its
   architecture, domains, role-based portals, and key workflows. A setup guide
   alone is not enough; document what the project _is_ and how it fits together.
2. Database seeds (`priv/repo/seeds.exs`) that give a new contributor a usable
   starting point with realistic data.

Before writing anything, build an accurate picture of the project by reading the
files listed under each task. The README should stay concise and link out to the
deeper docs; the deeper docs are where comprehensiveness lives.

---

## Task 1 — Inspect the project, then document it (README + deeper docs)

### Step 1.1 — Discover how this project is actually configured

Read these files and extract the real values (do not guess):

- `mix.exs` — the app name (`app: :...`), Elixir version requirement, dependencies, and the `aliases/0` function (note whether `ecto.setup` exists and whether it runs seeds; note any aliases that are intentionally blocked/overridden).
- `.credo.exs` — if missing, add a Credo config and add Credo to `mix.exs` for dev/test static analysis.
- `.tool-versions` — pinned Erlang/OTP and Elixir versions (if the file exists).
- `config/dev.exs` — the dev database config (username, password, hostname, database name) and the HTTP port.
- `config/config.exs` and `config/runtime.exs` — required environment variables / secrets, and which are dev-only vs. production-only.
- `assets/` and the `mix.exs` deps — whether the project uses the default esbuild + Tailwind asset pipeline, and whether `assets.setup` / `assets.build` aliases exist.
- The `lib/<app>_web/router.ex` — every route, scope, pipeline, and `live` route. This is the map of the application; use it to enumerate the portals/sections that exist.
- The `lib/<app>_web/` folder — LiveViews, controllers, components, and how authentication/authorization (roles, PINs, plugs, `on_mount` hooks) is wired.
- The `lib/<app>/` folder — the contexts (bounded domains) and Ecto schemas. List every context and the schemas it owns.
- `priv/repo/migrations/` — the real tables and relationships, to back up the data-model docs.
- Any `docker-compose.yml` or `Dockerfile` — if present, document the Docker path.

### Step 1.2 — Write `README.md` (concise entry point)

Create (or overwrite) `README.md` at the project root. Keep it tight — the goal is
"running in under five minutes" — but it must orient the reader, not just list
commands. Include:

1. **Project description** — 1–3 sentences on what the system is and who uses it,
   plus a short bullet list of the major areas/portals it contains (derived from
   the router and contexts, not invented).
2. **Prerequisites** — the actual Erlang/Elixir/Postgres/Node versions you found.
3. **Setup steps** using the project's real commands (prefer the `setup` /
   `ecto.setup` alias if it exists; otherwise spell the steps out).
4. **How to run the server** and the real local URL/port from `config/dev.exs`.
5. **Seeded logins** — the credentials the seeds create, in a table (see Task 2).
6. **Common commands** — test, format, Credo/static analysis, re-run seeds, asset build, plus any
   destructive aliases that are intentionally blocked and why.
7. **A "Documentation" section** linking to the deeper docs from Step 1.4, so the
   README stays short while pointing to where the real detail lives.

### Step 1.3 — If aliases are missing, fix them

If `mix.exs` doesn't already have aliases that make setup one command, add them so
the README can stay simple:

```elixir
defp aliases do
  [
    setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
    "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
    "ecto.reset": ["ecto.drop", "ecto.setup"],
    test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
  ]
end
```

Only add aliases that don't already exist; don't clobber existing ones.

### Step 1.4 — Document the system in depth (the comprehensive part)

A setup README is not enough. Produce documentation that explains what the system
**is** and how it fits together, so a new dev understands the project — not just
how to boot it. Put this depth in a `docs/` folder (keep the README short and link
to these). Create the files below that apply; only document what actually exists
in the repo.

- **`docs/ARCHITECTURE.md`** — A high-level overview:
  - The layers (web layer vs. business/context layer vs. Repo) and how a request
    flows through them.
  - A directory map of `lib/<app>/` and `lib/<app>_web/` with one line per
    important folder.
  - The tech stack and notable dependencies and what each is for.
  - How real-time/LiveView is used, if applicable.

- **`docs/DOMAINS.md`** (or one file per context) — For **each context/bounded
  domain** you found in `lib/<app>/`, document: its responsibility, the schemas it
  owns, the key public functions, and how it relates to other contexts. Enumerate
  every domain — do not summarize "and others."

- **`docs/PORTALS.md`** — The system has multiple role-based portals/sections.
  For each one visible in the router, document: who it's for (which role), the URL
  scope/path, the main screens/actions, and the LiveViews or controllers behind
  it. Cover every portal, e.g. (adapt to what the router actually shows): doctor,
  nurse, reception, pharmacy, laboratory, radiology, administration, inventory,
  procurement, suppliers, support staff, public website pages, payments, and
  medical-camp workflows.

- **`docs/AUTH.md`** — How authentication and authorization work: the user/role
  model, how roles map to portals, any PIN/secondary-auth mechanism, the relevant
  plugs / `on_mount` hooks / pipelines, and how a new role would be added.

- **`docs/DATA_MODEL.md`** — The core tables and their relationships (derive from
  migrations and schemas). A simple text or Mermaid ER description of the main
  entities (users, patients, visits, departments, rooms, suppliers, catalogs,
  inventory, payments, camps, etc. — whatever actually exists) and how they link.

- **`docs/WORKFLOWS.md`** — Walk through the few most important end-to-end flows
  in plain steps (e.g. a patient visit from reception → consultation → lab/
  pharmacy → payment, and the medical-camp flow). Tie each step to the portal and
  context that handles it.

- **`docs/ENVIRONMENT.md`** — Every environment variable and config the app reads,
  split into dev vs. production, which are required vs. optional, and what each
  controls. Include the intentionally-blocked destructive aliases and the reason.

Guidance for all docs:

- Be accurate and specific — reference real module names, paths, routes, and
  fields. If something is unclear from the code, mark it `TODO:` for a maintainer
  rather than guessing.
- Prefer short prose with small lists/tables over walls of text. Diagrams in
  Mermaid are welcome where they clarify (request flow, ER, a workflow).
- Don't paste large code blocks; describe behavior and point to the file.

---

## Task 2 — Create seeds (`priv/repo/seeds.exs`)

### Step 2.1 — Discover the real schemas and contexts

Read:

- `priv/repo/migrations/` — every table, its columns, and constraints.
- `lib/<app>/` — the Ecto schemas and context modules (e.g. `Accounts`, and
  functions like `register_user/1`, changesets, etc.).
- Any existing `priv/repo/seeds.exs` — extend it rather than discarding useful
  parts.

Use the **real** module names and fields. Do not invent schemas that don't exist.

### Step 2.2 — Write idempotent seeds

Create or update `priv/repo/seeds.exs` following these rules:

- **Idempotent:** running it twice must not crash or create duplicates. Use a
  "find or create" pattern (`Repo.get_by/2` then insert only if `nil`), not blind
  `Repo.insert!/1`.
- **Use context functions when they exist.** If there's a registration function
  (e.g. `Accounts.register_user/1`), call it so seeded records pass the same
  validations as real ones — instead of hand-rolling password hashing or
  inserting structs directly.
- **Minimal but realistic.** Seed enough to exercise the main flows: at least one
  admin/privileged user, one regular user, and a few rows of the core domain data.
- **Print a summary at the end**, including any login credentials a developer can
  use immediately (e.g. `admin@example.com / password1234`).

Reference pattern (adapt to the real schemas you found):

```elixir
alias <App>.Repo
# alias the real schemas/contexts you discovered

upsert = fn schema, lookup, attrs ->
  case Repo.get_by(schema, lookup) do
    nil -> schema |> struct(Map.merge(lookup, attrs)) |> Repo.insert!()
    record -> record
  end
end

# ... create users (prefer a context register function if one exists) ...
# ... create a few rows of core domain data ...

IO.puts("Seed complete. Log in with admin@example.com / password1234")
```

### Step 2.3 — Make sure seeds are wired in

Confirm the `ecto.setup` alias runs `run priv/repo/seeds.exs` so that
`mix ecto.setup` / `mix ecto.reset` load the data automatically (see Step 1.3).

---

## Task 3 — Create a basic pull request template

Create a `PULL_REQUEST.md` for the project so contributors have a consistent
format when opening PRs.

> Note: if the goal is for GitHub to auto-populate the PR description box,
> the conventional path is `.github/pull_request_template.md` (GitHub picks it
> up automatically). Use that location unless the maintainer specifically wants a
> root-level `PULL_REQUEST.md`. Pick the right one and mention which you used.

Keep it short and practical. Include these sections:

```markdown
## Summary

<!-- What does this PR do and why? One or two sentences. -->

## Changes

## <!-- Bullet list of the main changes. -->

## How to test

<!-- Steps a reviewer follows to verify this locally. -->

1.

## Checklist

- [ ] Ran `mix format`
- [ ] Ran `mix test` and tests pass
- [ ] Added/updated migrations and seeds if the schema changed
- [ ] Updated `README.md` / docs if setup or behavior changed
- [ ] No secrets or credentials committed

## Related issues

<!-- e.g. Closes #123 -->
```

Adapt the checklist to match the project's real tooling. This project should include
Credo, so add a `mix credo` checklist item. If it later uses `mix dialyzer` or a CI
step, add those lines too.

---

## Constraints

- Don't commit secrets or change committed dev credentials in `config/dev.exs`.
- Don't break existing migrations, aliases, or seed logic — extend them.
- Match the project's existing code style; run `mix format` on any Elixir you write.
- Use the project's real app/module names everywhere — no placeholders left in the
  final files (any unavoidable gaps should be explicit `TODO:` comments for the maintainer).

## Acceptance criteria (verify before finishing)

- [ ] A fresh clone can be set up by following `README.md` alone.
- [ ] `mix credo` is available, configured by `.credo.exs`, and documented in the README and PR template.
- [ ] `mix ecto.setup` creates the DB, migrates, and seeds without errors.
- [ ] Running the seeds a second time does not error or duplicate data.
- [ ] `mix phx.server` starts and the app is reachable at the documented URL.
- [ ] `README.md` lists the seeded login credentials so a new dev can log in immediately.
- [ ] `README.md` links to a `docs/` folder, and those docs cover architecture, every context/domain, every role portal, auth/roles, the data model, key workflows, and environment config.
- [ ] The docs reference real module names, routes, and fields — no invented or "and others" hand-waving; gaps are explicit `TODO:`s.
- [ ] A pull request template exists (at the chosen path) with the sections above.
- [ ] No invented schemas, fields, or commands — everything reflects the real repo.
