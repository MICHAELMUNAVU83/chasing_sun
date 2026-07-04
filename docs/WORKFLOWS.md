# Workflows

## New Developer Setup

1. Install local dependencies and PostgreSQL.
2. Run `npm install --prefix assets`.
3. Run `mix setup`.
4. Login at `http://localhost:4890/users/log_in` with `admin@gmail.com` / `123456`.
5. Review `/dashboard`, `/greenhouses`, `/harvest-records`, `/performance`, and admin screens.

## Greenhouse And Crop Cycle Management

1. Admin opens `/admin/ventures` to manage venture groups.
2. Admin or operator opens `/greenhouses`.
3. The LiveView calls `ChasingSun.Operations.create_greenhouse/3` or `update_greenhouse/4`.
4. The operation persists a greenhouse and active crop cycle in a transaction.
5. `CropPlanner` derives missing crop dates from `CropRule` data where possible.
6. An `AuditEvent` records the change and recommendation refresh is queued/triggered.

## Weekly Harvest Capture

1. Admin or operator opens `/harvest-records`.
2. The user selects greenhouse, week ending date, yield, and optional price/grade/notes.
3. `ChasingSun.Harvesting.create_harvest_record/2` inserts a new row or `upsert_harvest_record/2` updates an existing greenhouse/week row.
4. Harvesting resolves the active crop cycle through `Operations.resolve_current_cycle/2`.
5. Performance and forecast pages consume the new actuals.

## Performance Review And Export

1. User opens `/performance`.
2. `ChasingSun.Analytics.performance_report/1` loads harvest records and greenhouses.
3. `PerformanceReport` compares actual yield against crop-rule expected yield and calculates revenue using record price or crop-rule price.
4. User can export via `/performance/export`, handled by `PerformanceExportController` and `ChasingSun.Analytics.PerformanceExport`.

## Forecast And Recommendations

1. User opens `/forecast` or `/recommendations`.
2. `ChasingSun.Analytics.forecast/2` builds weekly forecast rows from active crop cycles.
3. `Operations.refresh_daily_operations/1` synchronizes statuses, recommendations, notifications, and continuous-harvest risks.
4. `RecommendationEngine` and `ExpansionEngine` suggest crop rotations or new greenhouse construction where rules and actual yield trends indicate a need.

## Farm Visit Reporting

1. Admin or operator opens `/farm-visits`.
2. The form captures report header data and a status row per greenhouse.
3. `Operations.upsert_farm_visit_report/2` creates or updates the report keyed by visit date.
4. Child `FarmVisitGreenhouseStatus` rows are cast through the report changeset and replaced as needed.
5. An audit event records insert/update.

## Guest Access

1. Admin opens `/admin/guests`.
2. Admin creates a guest user and chooses page, section, and venture visibility.
3. Guest logs in and lands on `/dashboard`.
4. `ChasingSun.Accounts.Scope` filters dashboard sections and allowed routes.
