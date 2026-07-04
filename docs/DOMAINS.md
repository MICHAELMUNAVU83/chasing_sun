# Domains

## Accounts

Main module: `ChasingSun.Accounts`

Schemas:

- `ChasingSun.Accounts.User`: email/password user with roles `:admin`, `:operator`, `:viewer`, and `:guest`; guest visibility fields `allowed_pages`, `allowed_sections`, and `allowed_venture_codes`.
- `ChasingSun.Accounts.UserToken`: session, email-change, reset-password, and confirmation tokens.

Key public functions:

- User lookup and login: `get_user_by_email/1`, `get_user_by_email_and_password/2`, `get_user!/1`
- Registration and role updates: `register_user/1`, `update_user_role/2`
- Guest management: `list_guest_users/0`, `create_guest_user/1`, `update_guest_user/2`, `delete_user/1`
- Settings/auth tokens: email, password, session, confirmation, and reset-password helpers.

Related module: `ChasingSun.Accounts.Scope` defines role permissions and guest page/section/venture visibility.

## Operations

Main module: `ChasingSun.Operations`

Schemas:

- `Venture`: business grouping, currently seeded as `cs` and `csg`.
- `Greenhouse`: production unit with sequence, name, size, tank, active flag, and venture.
- `CropCycle`: active or historical crop program for a greenhouse.
- `CropRule`: crop planning defaults, expected yields, varieties, and prices.
- `OperationRecommendation`: one current recommendation per greenhouse.
- `OperationNotification`: dated operational alert.
- `FarmVisitReport`: farm visit header and summary.
- `FarmVisitGreenhouseStatus`: per-greenhouse status captured in a visit.
- `AuditEvent`: audit trail for important operations.

Key public functions:

- Ventures: `list_ventures/0`, `list_ventures_with_greenhouses/0`, `create_venture/2`, `update_venture/3`, `delete_venture/2`, `ensure_venture_seeded/0`
- Crop rules: `list_crop_rules/0`, `create_crop_rule/2`, `update_crop_rule/3`, `crop_types/0`, `crop_varieties/2`, `default_variety_for_crop/2`
- Greenhouses/cycles: `list_greenhouses/1`, `get_greenhouse!/1`, `create_greenhouse/3`, `update_greenhouse/4`, `delete_greenhouse/2`, `terminate_production/3`
- Recommendations/notifications: `refresh_daily_operations/1`, `list_operation_recommendations/1`, `recent_operation_notifications/2`, `expansion_recommendations/1`
- Dashboard and audit: `dashboard_snapshot/1`, `recent_audit_events/1`
- Farm visits: `list_farm_visit_reports/1`, `get_farm_visit_report!/1`, `get_farm_visit_report_by_date/1`, `upsert_farm_visit_report/2`, `update_farm_visit_report/3`

Supporting modules include `CropPlanner`, `StatusCalculator`, `RecommendationEngine`, and `ExpansionEngine`.

## Harvesting

Main module: `ChasingSun.Harvesting`

Schema:

- `ChasingSun.Harvesting.HarvestRecord`: weekly harvest actuals with greenhouse, crop cycle, week ending date, yield, optional price, grade, notes, and inserted user.

Key public functions:

- `list_harvest_records/1`
- `recent_records/1`
- `latest_week_summary/1`
- `change_harvest_record/2`
- `create_harvest_record/2`
- `upsert_harvest_record/2`
- `update_harvest_record/3`

Harvest writes attach the current crop cycle where possible and create audit events when an actor is supplied.

## Analytics

Main module: `ChasingSun.Analytics`

Supporting modules:

- `ForecastEngine`: next-week forecast rows for active harvesting units.
- `ProjectionEngine`: weighted projections using recent actuals.
- `PerformanceReport`: expected vs actual yield, revenue, variance, month/week/season filters, and insights.
- `PerformanceExport`: SpreadsheetML workbook export for reports.

Key public functions:

- `dashboard/1`
- `performance_report/1`
- `next_saturday_projection/1`
- `forecast/2`

Analytics depends on Operations for crop rules, greenhouse state, and recommendations, and on Harvesting for actual yield rows.

## Importing

Main module: `ChasingSun.Importing`

Supporting modules:

- `ChasingSun.Importing.LegacyJsonImporter`
- `ChasingSun.Workers.LegacyImportWorker`

Key public functions:

- `import_now/1`
- `enqueue_import/1`

The async path uses Oban queue `:imports`.
