# Chasing Sun — Technology Build Spec (Phoenix LiveView)

**Subsidiary:** Chasing Sun (Horticulture & Commodity Trading)
**Submitted by:** Josiah Stanley — 04/07/26
**Business model:** B2B horticulture + commodity trading enterprise. Farm operations in Naivasha (greenhouse produce) + commodity trading across East Africa. Clients are B2B, trading in 1MT+ volumes: packhouses, hotels, specialty tea companies, spice companies.

**App name suggestion:** `ChasingSunOps`

---

## 1. Current State (context for the build)

- Comms: WhatsApp + Email — no system of record, decisions/approvals get lost.
- Existing farm dashboard (external, keep separate): https://www.dashboard.chasingsun.africa/dashboard — handles crop planting, greenhouse monitoring, weekly revenue collection. **Do not rebuild this — extend it.**
- Financials: multiple disconnected MS Excel sheets, one set for commodity trade, one for horticulture. No single daily/weekly/monthly view.
- Documents: siloed on individual employee computers, organized informally by department (Operations, Finance, Marketing). C-suite/oversight has no direct access — must go through staff.

---

## 2. Business Domains & Data Model

### 2.1 Finance Module (Priority: **High**)

**Purpose:** give an accountant a place to record transactions daily, and give C-suite a real-time read of financial position — replacing the Excel sheets entirely.

**Users & roles:**

- `accountant` — full CRUD on transactions, invoices, delivery notes
- `executive` (C-suite) — read-only dashboard + drill-down, cannot edit
- `admin` — user management, both of the above plus settings

**Core entities (Ecto schemas):**

```
Transaction
  - id
  - type          (enum: :revenue | :expense)
  - business_line (enum: :horticulture | :commodity)
  - amount         :decimal
  - currency       :string, default "KES"
  - description    :string
  - client_id      references Client (nullable for expenses)
  - category       :string  (e.g. "seed_cost", "transport", "sale")
  - occurred_on    :date
  - recorded_by_id references User
  - inserted_at / updated_at

Client
  - id
  - name
  - type           (enum: :packhouse | :hotel | :tea_company | :spice_company | :other)
  - contact_person
  - phone
  - email

Invoice
  - id
  - client_id       references Client
  - transaction_id  references Transaction (nullable — invoice can precede payment)
  - invoice_number  :string, unique
  - status          (enum: :draft | :sent | :paid | :overdue)
  - due_date        :date
  - line_items      (embedded schema: description, quantity, unit_price, total)
  - pdf_url         :string (generated file, see PDF skill for generation)

DeliveryNote
  - id
  - order_reference :string
  - client_id       references Client
  - items           (embedded schema: product, quantity_mt, unit)
  - dispatched_on   :date
  - signed_by       :string
  - status          (enum: :pending | :delivered | :disputed)
```

**LiveView routes & pages:**
| Route | LiveView | Purpose |
|---|---|---|
| `/finance` | `FinanceDashboardLive` | Cards: today/week/month revenue & expense, split by business line; trend chart (last 12 weeks) |
| `/finance/transactions` | `TransactionsLive.Index` | Filterable/sortable table (date range, business line, category, client); inline "Add Transaction" form via `live_component` |
| `/finance/transactions/:id/edit` | `TransactionsLive.Edit` | Edit single transaction (accountant only) |
| `/finance/invoices` | `InvoicesLive.Index` | List with status badges; "Generate Invoice" action |
| `/finance/invoices/new` | `InvoicesLive.New` | Build invoice from client + line items, generates PDF on save |
| `/finance/delivery-notes` | `DeliveryNotesLive.Index` | List + create delivery notes tied to an order |

**Business rules:**

- Executives see `FinanceDashboardLive` only — redirect attempted edits.
- Dashboard must update live (via `Phoenix.PubSub.broadcast/3` on transaction insert) so C-suite sees numbers change without refreshing.
- Invoice numbers auto-increment per year (e.g. `CS-2026-0001`).
- Overdue status computed nightly (Oban job or simple `Ecto` query on load) comparing `due_date` to today.

**Acceptance criteria (example, write more per feature as needed):**

- Given an accountant logs a KES 50,000 revenue transaction for horticulture today, the `FinanceDashboardLive` "This Week" card updates within 2 seconds without page reload, for any connected executive session.
- Given an invoice is marked "paid", its linked transaction (if none exists) is auto-created as a revenue transaction.

---

### 2.2 Document Centralization (Priority: Medium)

**Purpose:** single place for C-suite to access all department documents instantly, without requesting access from individual staff.

**Core entity:**

```
Document
  - id
  - department     (enum: :operations | :finance | :marketing | :other)
  - title
  - file_url        (stored via S3-compatible bucket or local /priv/uploads in dev)
  - uploaded_by_id  references User
  - visibility      (enum: :department_only | :leadership | :all_staff)
  - tags            {:array, :string}
  - inserted_at
```

**LiveView routes:**
| Route | LiveView | Purpose |
|---|---|---|
| `/documents` | `DocumentsLive.Index` | Folder-style browse by department, search by title/tag |
| `/documents/upload` | live_component modal | Drag-drop upload (use `Phoenix.LiveView.UploadEntry`) |

**Business rules:**

- C-suite role bypasses `department_only` visibility restriction.
- Uploads validated for file type (pdf, docx, xlsx, csv, images) and max size (e.g. 20MB).

---

### 2.3 Greenhouse IoT Extension (Priority: Medium)

**Purpose:** extend the _existing_ external dashboard with real-time sensor telemetry — this is additive, not a replacement.

**Metrics to ingest:** soil moisture (%), humidity (%), greenhouse temperature (°C), wind speed (km/h)

**Core entity:**

```
SensorReading
  - id
  - greenhouse_id
  - sensor_type    (enum: :soil_moisture | :humidity | :temperature | :wind_speed)
  - value           :float
  - unit            :string
  - recorded_at     :utc_datetime
```

High write volume — consider a separate ingestion pipeline (Broadway or a simple Plug endpoint) rather than routing hardware writes through LiveView.

**LiveView routes:**
| Route | LiveView | Purpose |
|---|---|---|
| `/greenhouse` | `GreenhouseLive` | Live tiles per metric (current value + sparkline), updated via `Phoenix.PubSub.subscribe("greenhouse:readings")` |
| `/greenhouse/history` | `GreenhouseHistoryLive` | Daily/weekly trend charts per metric (use a JS charting hook — Chart.js or similar via a LiveView hook) |

**Architecture note:**

1. IoT gateway posts readings to an ingestion endpoint (`POST /api/sensor_readings`).
2. Endpoint inserts into DB and broadcasts via PubSub.
3. `GreenhouseLive` subscribes and patches the socket assigns — no polling.

**Business rules:**

- Alert thresholds (e.g. soil moisture < 20%) should trigger a visible banner on `GreenhouseLive` and could later extend to SMS/WhatsApp alerts (matches their existing WhatsApp-first culture).

---

## 3. Hardware Requirements (non-dev, track as tasks not features)

- Microphones for Marketing videos — Low priority
- Replacement phone for CS team — Low priority (not urgent)

---

## 4. Industry Benchmarks (design inspiration)

| Company                                 | System                                                          | What to borrow for this build                                                                          |
| --------------------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Smeding Groenten en Fruit (Netherlands) | SAP S/4HANA                                                     | Unified procurement/sales/logistics/financial view → mirror in Finance Module's dashboard-first design |
| Sundrop Farms (Australia)               | Init tailored greenhouse automation (case study: initgroup.com) | Sensor-to-dashboard real-time monitoring pattern → mirror in Greenhouse IoT extension                  |

---

## 5. Suggested Build Order

1. **Phase 1 (High):** Finance Module — Transactions, Dashboard, Invoices, Delivery Notes
2. **Phase 2 (Medium):** Document Centralization
3. **Phase 2 (Medium, parallel):** Greenhouse IoT ingestion + `GreenhouseLive`
4. **Phase 3 (Low, non-dev):** Hardware procurement

## 6. Roles Summary (for `Accounts` context)

| Role         | Access                                                                     |
| ------------ | -------------------------------------------------------------------------- |
| `accountant` | Finance CRUD                                                               |
| `executive`  | Finance read-only, Documents (leadership visibility), Greenhouse read-only |
| `operations` | Documents (operations dept), Greenhouse read-only                          |
| `admin`      | Everything + user management                                               |

## 7. Open Questions to Resolve Before/During Build

- What IoT hardware/protocol will send sensor data (MQTT vs HTTP webhook)? Determines ingestion architecture.
- Should invoices/delivery notes be emailed automatically on generation, or manually sent via WhatsApp/Email as today?
- Multi-currency needed, or KES only for now?
