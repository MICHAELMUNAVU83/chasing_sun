# Portals

## Public

Path scope: `/`

Routes:

- `GET /` -> `ChasingSunWeb.PageController.home`

The public home page is available without authentication.

## Account Flows

Path scope: `/users`

Controllers:

- `UserRegistrationController`: register a new user.
- `UserSessionController`: login/logout.
- `UserResetPasswordController`: request and complete password reset.
- `UserSettingsController`: email/password settings for authenticated users.
- `UserConfirmationController`: email confirmation flow.

Authenticated users are redirected to `/dashboard`.

## Dashboard Portal

Path: `/dashboard`

LiveView: `ChasingSunWeb.DashboardLive.Index`

Access:

- Requires a logged-in user.
- Guests can reach the dashboard, but section visibility is restricted by `allowed_sections`.

Purpose:

- Operational summary, greenhouse status, charts, quick view, recommendations, notifications, and next-Saturday outlook.

## Operations Portal

Path scope: `/`

Access:

- LiveViews use `:ensure_operations_access`.
- Admin, operator, and viewer roles can access operations pages through `ChasingSun.Accounts.Scope`.
- Guest access is limited to grantable read-only pages: `forecast` and `recommendations`.

Routes:

| Path | Handler | Purpose |
| --- | --- | --- |
| `/recommendations` | `ChasingSunWeb.RecommendationLive.Index` | Crop rotation and expansion recommendations |
| `/greenhouses` | `ChasingSunWeb.GreenhouseLive.Index` | Greenhouse list and management |
| `/greenhouses/:id` | `ChasingSunWeb.GreenhouseLive.Show` | Single greenhouse detail |
| `/farm-visits` | `ChasingSunWeb.FarmVisitLive.Index` | Farm visit reports and greenhouse status checks |
| `/harvest-records` | `ChasingSunWeb.HarvestRecordLive.Index` | Weekly harvest entry |
| `/performance` | `ChasingSunWeb.PerformanceLive.Index` | Yield, revenue, variance, and insights |
| `/forecast` | `ChasingSunWeb.ForecastLive.Index` | Eight-week forecast and projections |
| `/performance/export` | `ChasingSunWeb.PerformanceExportController.show` | Spreadsheet export for performance data |

## Admin Portal

Path scope: `/admin`

Access:

- Uses `:ensure_admin`.
- The check is currently `Scope.can?(user, :manage_crop_rules)`, which only admins have.

Routes:

| Path | Handler | Purpose |
| --- | --- | --- |
| `/admin/guide` | `ChasingSunWeb.Admin.GuideLive.Index` | In-app operations guide |
| `/admin/ventures` | `ChasingSunWeb.Admin.VentureLive.Index` | Venture management |
| `/admin/crop-rules` | `ChasingSunWeb.Admin.CropRuleLive.Index` | Crop planning rules, varieties, yields, and prices |
| `/admin/guests` | `ChasingSunWeb.Admin.GuestLive.Index` | Restricted guest account management |

## Development Tools

Enabled only when `config :chasing_sun, dev_routes: true`:

- `/dev/dashboard` -> Phoenix LiveDashboard
- `/dev/mailbox` -> Swoosh mailbox preview
