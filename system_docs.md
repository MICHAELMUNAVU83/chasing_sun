# ChasingSun Improved System Document

## Purpose

This document defines the improved version of ChasingSun as a new Phoenix LiveView and Elixir application. It is intended to be used as the build spec for a new project, not as documentation for the current Flask codebase.

The new system should preserve the current business behavior where it is already correct, while fixing the architectural weaknesses of the existing implementation.

## Product Goal

Build an internal greenhouse operations platform that helps operators:

1. Manage greenhouse production cycles.
2. Track weekly actual harvest performance.
3. Monitor current operational state across all units.
4. Forecast expected output for the next 8 weeks.
5. Plan next crop actions after each harvest cycle.

This should remain a focused operations dashboard, not a full farm ERP.

## Target Stack

- Language: Elixir
- Web framework: Phoenix
- UI framework: Phoenix LiveView
- Database: PostgreSQL
- ORM/data layer: Ecto
- Background jobs: Oban
- Authentication: Phoenix-generated auth with role-based access
- Charts/tables: LiveView-friendly server-rendered components
- Deployment target: Fly.io, Render, Railway, or a standard container platform

## Why This Rebuild Is Better

The current project works, but it has structural limits:

- business logic is embedded in one file
- persistence is JSON-only
- no transaction boundaries exist
- no tests exist
- no audit history exists
- no real separation exists between domain logic and UI

The new Phoenix version should improve this by introducing:

- clear domain contexts
- validated schemas and changesets
- transactional writes
- real relational data modeling
- live dashboards with immediate updates
- testable business rules
- import path from the old JSON files

## Product Scope

### In Scope

- greenhouse registry
- crop cycle planning
- weekly harvest data entry
- performance analytics
- venture filtering
- next 8 weeks forecast
- next crop recommendations
- basic authentication and authorization
- auditability of critical edits

### Out of Scope For V1

- inventory management
- irrigation automation
- pest and disease records
- finance beyond simple revenue estimation
- mobile offline sync
- external IoT integrations

## Core Domain Model

### 1. Venture

Represents the business grouping for greenhouse units.

Fields:

- id
- code: `cs` or `csg`
- name

Rules:

- Existing venture mapping from the old app should be preserved initially.
- The new app should store venture explicitly in the database instead of inferring it only from greenhouse name.

### 2. Greenhouse

Represents one greenhouse unit.

Fields:

- id
- sequence_no
- name
- size
- tank
- venture_id
- active
- inserted_at
- updated_at

Constraints:

- `sequence_no` unique
- `name` unique

### 3. Crop Cycle

Represents the current or historical crop program for a greenhouse.

Fields:

- id
- greenhouse_id
- crop_type
- variety
- plant_count
- nursery_date
- transplant_date
- harvest_start_date
- harvest_end_date
- soil_recovery_end_date
- status_cache
- inserted_at
- updated_at

Why split this from greenhouse:

- the current Flask app stores crop state directly on the greenhouse record
- that makes historical reporting weak
- the new design should allow multiple cycles over time per greenhouse

### 4. Harvest Record

Represents actual weekly output for a greenhouse crop cycle.

Fields:

- id
- greenhouse_id
- crop_cycle_id
- week_ending_on
- actual_yield
- notes
- inserted_by_user_id
- inserted_at
- updated_at

Constraints:

- unique on `greenhouse_id + week_ending_on`

### 5. Crop Rule

Represents system-managed crop planning defaults.

Fields:

- id
- crop_type
- nursery_days
- days_to_harvest
- harvest_period_days
- default_variety
- forced_size
- expected_yield_1000
- expected_yield_2000
- flat_expected_yield
- price_per_unit
- active

This can be seeded into the database, but the app should expose it through a dedicated domain module rather than scattering constants.

### 6. Audit Event

Represents important user actions.

Fields:

- id
- actor_user_id
- entity_type
- entity_id
- action
- metadata
- inserted_at

Track at least:

- greenhouse created
- greenhouse updated
- greenhouse deleted
- harvest record inserted
- harvest record updated
- cycle end date updated

## Phoenix Contexts

The new app should be split into explicit contexts.

### Operations Context

Responsibilities:

- greenhouse management
- venture assignment
- crop cycle lifecycle
- status calculation
- next crop recommendation

Suggested modules:

- `ChasingSun.Operations`
- `ChasingSun.Operations.Greenhouse`
- `ChasingSun.Operations.CropCycle`
- `ChasingSun.Operations.Venture`
- `ChasingSun.Operations.StatusCalculator`
- `ChasingSun.Operations.CropPlanner`

### Harvesting Context

Responsibilities:

- weekly harvest entry
- upsert logic per greenhouse and week
- recent performance lookup

Suggested modules:

- `ChasingSun.Harvesting`
- `ChasingSun.Harvesting.HarvestRecord`
- `ChasingSun.Harvesting.RecordUpserter`

### Analytics Context

Responsibilities:

- expected vs actual comparison
- revenue estimates
- monthly grouping
- trend projections
- forecast generation

Suggested modules:

- `ChasingSun.Analytics`
- `ChasingSun.Analytics.PerformanceReport`
- `ChasingSun.Analytics.ForecastEngine`
- `ChasingSun.Analytics.ProjectionEngine`

### Accounts Context

Responsibilities:

- users
- authentication
- roles and authorization

Suggested modules:

- `ChasingSun.Accounts`
- `ChasingSun.Accounts.User`
- `ChasingSun.Accounts.Scope`

### Importer Context

Responsibilities:

- import old `greenhouses.json`
- import old `data.json`
- normalize legacy rows into new tables

Suggested modules:

- `ChasingSun.Importing`
- `ChasingSun.Importing.LegacyJsonImporter`

## Business Rules To Preserve

These rules come from the existing app and should remain the system default.

### Crop Rules

#### Capsicum

- nursery to transplant: 45 days
- transplant to harvest start: 90 days
- harvest duration: 150 days
- default variety: `Passarella / Ilanga`
- expected weekly yield for 1000 plants: 200
- expected weekly yield for 2000 plants: 350
- price per unit: 120

#### Cucumber

- transplant to harvest start: 45 days
- harvest duration: 120 days
- expected weekly yield for 1000 plants: 400
- expected weekly yield for 2000 plants: 700
- price per unit: 90

#### Local Cucumber

- transplant to harvest start: 60 days
- harvest duration: 90 days
- forced variety: `Mydas RZ`
- forced size: `16x40`
- expected weekly yield: 600
- price per unit: 90

#### Asparagus

- expected weekly yield: 150
- price per unit: 600
- no automatic nursery/transplant timeline should be assumed beyond stored dates unless new agronomic rules are later added

### Status Rules

Each current crop cycle must resolve to one of three statuses:

- `harvesting`
- `soil_turning`
- `waiting`

Rules:

- `harvesting`: today is between `harvest_start_date` and `harvest_end_date`, inclusive
- `soil_turning`: today is after `harvest_end_date` and on or before `soil_recovery_end_date`
- `waiting`: all other cases

Default soil recovery duration remains 30 days after `harvest_end_date`.

### Next Crop Recommendation Rules

- current `Cucumber` or `Local Cucumber` -> recommend `Capsicum`
- current `Capsicum` -> recommend `Cucumber`
- all other crops -> recommend `Capsicum`

### Actual Harvest Entry Rules

- one record per greenhouse per week ending date
- if the record already exists, update it instead of inserting a duplicate
- actual yield must be numeric and non-negative
- crop and greenhouse linkage should come from relational references, not copied strings

### Projection Rules

For the next-Saturday projection:

- target the next Saturday after today
- include only greenhouses harvesting on that date
- use up to 3 recent harvest records per greenhouse
- more recent values get more weight
- cap projected value at 140% of expected weekly yield
- if there is no recent data, fall back to expected yield

## Improvements Over The Current Product

### 1. Separate Greenhouse From Crop Cycle

The existing app stores the active crop directly on the greenhouse row. The new app should move crop planning into a `crop_cycles` table so the system can retain history and support reporting across seasons.

### 2. Explicit Venture Ownership

The old app infers venture from greenhouse names. The new app should store venture directly while still supporting legacy import mapping.

### 3. Safe, Validated Writes

All mutations should happen through Ecto changesets and transactions. This removes fragile direct JSON rewrites.

### 4. Live UI Instead Of Post/Redirect Everywhere

The new app should use LiveView for the main operational screens so users can:

- filter ventures without full reloads
- edit records inline
- see summary cards refresh instantly
- manage forms with live validation

### 5. Better Reporting Model

The old app computes reports in route handlers. The new app should move this into dedicated analytics modules with reusable query functions.

### 6. Import And Seed Path

The new app should support bootstrapping from the current JSON files so the existing data is not lost during migration.

## LiveView Screens

### 1. Dashboard LiveView

Route suggestion: `/dashboard`

Purpose:

- show current greenhouse operational state
- display summary cards
- support venture filter tabs
- allow quick edit of greenhouse cycle details

Components:

- summary KPI cards
- venture filter tabs
- greenhouse status table
- quick actions drawer or modal

Key interactions:

- filter by venture with no page reload
- open modal to edit greenhouse or cycle
- extend end date inline

### 2. Greenhouse Registry LiveView

Route suggestion: `/greenhouses`

Purpose:

- manage greenhouse master records
- create new greenhouse units
- view current and historical crop cycles

Components:

- registry table
- create/edit greenhouse modal
- cycle history panel

### 3. Harvest Input LiveView

Route suggestion: `/harvest-records`

Purpose:

- capture weekly actual yields
- upsert records without navigating away

Components:

- date selector
- greenhouse selector
- yield input form
- recent entries table
- validation and success state in-place

### 4. Performance LiveView

Route suggestion: `/performance`

Purpose:

- compare actual vs expected output
- show revenue estimate
- group by month
- support inline yield edits

Components:

- summary cards
- venture filter tabs
- next-Saturday projection card
- monthly grouped table
- inline edit modal

### 5. Forecast LiveView

Route suggestion: `/forecast`

Purpose:

- show 8-week forward production plan
- show active units per week
- show next crop recommendations

Components:

- forecast summary cards
- weekly forecast table
- expandable active unit rows
- recommendation cards

### 6. Admin LiveView For Crop Rules

Route suggestion: `/admin/crop-rules`

Purpose:

- view and manage crop planning defaults
- allow agronomic rules to evolve without code edits

This screen can be admin-only and may be deferred to V1.1 if time is tight.

## Database Design

### ventures

- id
- code
- name
- inserted_at
- updated_at

### greenhouses

- id
- sequence_no
- name
- size
- tank
- venture_id
- active
- inserted_at
- updated_at

### crop_cycles

- id
- greenhouse_id
- crop_type
- variety
- plant_count
- nursery_date
- transplant_date
- harvest_start_date
- harvest_end_date
- soil_recovery_end_date
- status_cache
- archived_at
- inserted_at
- updated_at

### harvest_records

- id
- greenhouse_id
- crop_cycle_id
- week_ending_on
- actual_yield
- notes
- inserted_by_user_id
- inserted_at
- updated_at

### crop_rules

- id
- crop_type
- nursery_days
- days_to_harvest
- harvest_period_days
- default_variety
- forced_size
- expected_yield_1000
- expected_yield_2000
- flat_expected_yield
- price_per_unit
- active
- inserted_at
- updated_at

### audit_events

- id
- actor_user_id
- entity_type
- entity_id
- action
- metadata
- inserted_at

## Query And Calculation Strategy

### Expected Yield

Implement a single source of truth in `CropPlanner.expected_yield/2` or similar:

- asparagus -> flat 150
- local cucumber -> flat 600
- cucumber -> plant-count-sensitive
- capsicum -> plant-count-sensitive

### Revenue

Revenue remains a simple estimate for now:

$$
revenue = actual\_yield \times price\_per\_unit
$$

### Variance

$$
variance = actual - expected
$$

$$
variance\_pct = \frac{actual - expected}{expected} \times 100
$$

If expected is zero, variance percentage should resolve to zero rather than error.

### Weighted Projection

For up to 3 most recent records ordered oldest to newest:

$$
projection = \frac{\sum(value_i \times weight_i)}{\sum(weight_i)}
$$

where weights are $1, 2, 3$ for oldest to newest.

Then apply cap:

$$
projection = \min(\max(projection, 0), expected \times 1.4)
$$

## Authorization Model

Recommended roles:

- `admin`: full access, crop rules, users, deletion
- `operator`: manage greenhouse cycles and harvest entries
- `viewer`: read-only access to dashboards and reports

Minimum rules:

- only admin can delete greenhouse units
- only admin and operator can create or edit harvest data
- viewers cannot mutate data

## UX Expectations

The UI should feel operational, fast, and dense without being cluttered.

Design direction:

- desktop-first but mobile-usable
- strong tables and summary cards
- clear color semantics for status:
  - harvesting -> green
  - soil turning -> amber
  - waiting -> gray or blue
- modals and side panels for editing
- avoid page-by-page reload workflows where LiveView can handle the interaction

## Migration Plan From Current JSON App

### Input Sources

- `greenhouses.json`
- `data.json`

### Import Strategy

1. Seed ventures.
2. Import greenhouse records.
3. Create one active crop cycle per imported greenhouse based on the current stored fields.
4. Compute `soil_recovery_end_date` during import.
5. Import weekly harvest rows and attach them to the appropriate greenhouse and active crop cycle.
6. Preserve old dates exactly unless invalid.

### Legacy Venture Mapping

Import these names as `cs` venture:

- Tharakanithi
- Meru
- Kisii

All other names import as `csg` initially.

## Suggested Phoenix Project Structure

Suggested app name:

- `chasing_sun`

Suggested modules:

- `ChasingSun.Application`
- `ChasingSun.Repo`
- `ChasingSun.Operations`
- `ChasingSun.Harvesting`
- `ChasingSun.Analytics`
- `ChasingSun.Importing`
- `ChasingSunWeb.Router`
- `ChasingSunWeb.DashboardLive.Index`
- `ChasingSunWeb.GreenhouseLive.Index`
- `ChasingSunWeb.HarvestRecordLive.Index`
- `ChasingSunWeb.PerformanceLive.Index`
- `ChasingSunWeb.ForecastLive.Index`
- `ChasingSunWeb.Components.StatusBadge`
- `ChasingSunWeb.Components.SummaryCard`

## Testing Requirements

The new project should include automated tests from the start.

### Unit Tests

- crop rule date derivation
- expected yield logic
- price lookup logic
- status resolution
- next crop recommendation
- weighted projection behavior

### Context Tests

- greenhouse creation and validation
- crop cycle normalization
- harvest upsert logic
- import of legacy JSON

### LiveView Tests

- venture filtering
- greenhouse creation form validation
- harvest entry updates
- performance inline edit flow
- forecast rendering

## Non-Functional Requirements

- use UTC internally where timestamps matter
- use `Date` for agronomic day-based fields, not full datetime unless needed
- all domain writes must go through changesets
- all important writes should emit audit events
- pages should load quickly with fewer than 100 greenhouse units in V1
- calculations should be deterministic and test-covered

## V1 Delivery Checklist

The first production-ready version should include:

1. authentication
2. greenhouse registry
3. crop cycle management
4. harvest input upsert flow
5. dashboard with venture filters
6. performance report with monthly grouping
7. forecast page with 8-week output
8. next-Saturday projection card
9. legacy JSON importer
10. baseline test coverage

## Final Build Intent

The new project should feel like a proper internal operations product built on Elixir strengths:

- stateful real-time UI with LiveView
- reliable data modeling with Ecto
- maintainable domain boundaries
- strong validation
- simple deployment
- room to grow without rewriting the core

This is the target system document for the new project.
