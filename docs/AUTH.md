# Authentication And Authorization

Authentication is Phoenix-generated email/password auth in `ChasingSun.Accounts` and `ChasingSunWeb.UserAuth`.

## User Model

`ChasingSun.Accounts.User` stores:

- `email`
- `hashed_password`
- `confirmed_at`
- `role`: `:admin`, `:operator`, `:viewer`, `:guest`, `:accountant`, or `:executive`
- Guest restrictions: `allowed_pages`, `allowed_sections`, `allowed_venture_codes`

Passwords are hashed with `bcrypt_elixir`.

## Sessions

`ChasingSunWeb.UserAuth`:

- writes session tokens with `Accounts.generate_user_session_token/1`
- supports a signed remember-me cookie named `_chasing_sun_web_user_remember_me`
- assigns `:current_user` in the browser pipeline through `fetch_current_user/2`
- disconnects LiveViews on logout via the `live_socket_id`

## Role Permissions

Permissions are defined in `ChasingSun.Accounts.Scope`.

| Role | Permissions |
| --- | --- |
| `:admin` | Dashboard, operations, greenhouse management, harvest management, farm visits, crop rules, greenhouse deletion |
| `:operator` | Dashboard, operations, greenhouse management, harvest management, farm visits |
| `:viewer` | Dashboard and operations read access |
| `:guest` | Dashboard only, plus optional grantable read-only pages |
| `:accountant` | Finance dashboard, full CRUD on transactions/invoices/delivery notes |
| `:executive` | Read-only finance dashboard + drill-down, documents (bypasses `department_only` visibility) |

Grantable guest pages are `forecast` and `recommendations`. Guest dashboard sections and venture visibility are stored per user.

## Router Enforcement

The browser pipeline fetches the current user.

Live sessions:

- `:authenticated`: `on_mount {UserAuth, :ensure_authenticated}` for `/dashboard`.
- `:operations`: `on_mount {UserAuth, :ensure_operations_access}` for operations routes.
- `:admin`: `on_mount {UserAuth, :ensure_admin}` for admin routes.
- `:finance`: `on_mount {UserAuth, :ensure_finance_access}` for read-only finance routes (requires `:view_finance_dashboard`).
- `:finance_management`: `on_mount {UserAuth, :ensure_finance_management}` for finance edit/create routes (requires `:manage_finance`; redirects executives back to `/finance`).
- `:documents`: `on_mount {UserAuth, :ensure_document_access}` for `/documents` (requires `:view_documents`).

Controller scopes use:

- `redirect_if_user_is_authenticated`
- `require_authenticated_user`

## Adding A Role

1. Add the role atom to `ChasingSun.Accounts.User`'s `Ecto.Enum`.
2. Add a `permissions/1` clause in `ChasingSun.Accounts.Scope`.
3. Decide whether the role should have unrestricted operations access or guest-style restrictions.
4. Update any UI role selectors and seeded accounts.
5. Add route or LiveView checks if the role needs a new portal.
6. Add or update tests for the new permission matrix.

There is no PIN or secondary-auth mechanism in the current codebase.
