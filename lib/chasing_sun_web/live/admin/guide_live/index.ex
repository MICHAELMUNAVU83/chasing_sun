defmodule ChasingSunWeb.Admin.GuideLive.Index do
  use ChasingSunWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Admin Guide")
     |> assign(:workflow_steps, workflow_steps())
     |> assign(:page_guides, page_guides())
     |> assign(:diagnostics, diagnostics())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-6">
      <div class="grid gap-6 xl:grid-cols-[minmax(0,1.45fr)_minmax(320px,1fr)]">
        <div class="panel-shell">
          <p class="eyebrow">Admin Guide</p>
          <h1 class="page-title">How to manage ChasingSun without guessing</h1>
          <p class="page-copy">
            This page explains what each operational screen controls, what admins should edit there,
            and what to check first when numbers look wrong.
          </p>

          <div class="mt-8 grid gap-4 md:grid-cols-1">
            <.summary_card
              title="Admin-only pages"
              value="2"
              hint="Guide and crop rules"
            />
            <.summary_card
              title="Core operating screens"
              value="5"
              hint="Dashboard, greenhouses, harvest, performance, forecast"
              accent="yellow"
            />
            <.summary_card
              title="Best rule"
              value="Edit causes upstream changes"
              hint="Crop rules, cycles, and harvests drive most analytics"
              accent="ink"
            />
          </div>
        </div>

        <div class="panel-shell">
          <p class="eyebrow">Operating Order</p>
          <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
            Recommended admin workflow
          </h2>

          <div class="mt-6 space-y-4">
            <div
              :for={{step, index} <- Enum.with_index(@workflow_steps, 1)}
              class="rounded-[1.5rem] border border-[var(--line)] bg-[var(--surface-soft)] p-4"
            >
              <p class="text-xs font-semibold uppercase tracking-[0.22em] text-[var(--muted)]">
                Step {index}
              </p>
              <p class="mt-2 text-base font-semibold text-[var(--ink)]">{step.title}</p>
              <p class="mt-2 text-sm leading-6 text-[var(--muted)]">{step.detail}</p>
            </div>
          </div>
        </div>
      </div>

      <div class="panel-shell">
        <p class="eyebrow">Page Guide</p>
        <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
          What each page does and what to edit there
        </h2>

        <div class="mt-6 grid gap-4 s">
          <article
            :for={page <- @page_guides}
            class="rounded-[1.75rem] border border-[var(--line)] bg-white/90 p-5"
          >
            <div class="flex items-start justify-between gap-4">
              <div>
                <p class="text-xs font-semibold uppercase tracking-[0.22em] text-[var(--muted)]">
                  {page.section}
                </p>
                <h3 class="mt-2 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
                  {page.title}
                </h3>
              </div>
              <.link navigate={page.path} class="action-link">Open page</.link>
            </div>

            <p class="mt-4 text-sm leading-6 text-[var(--muted)]">{page.summary}</p>

            <div class="mt-5 grid gap-4 lg:grid-cols-2">
              <div class="rounded-[1.25rem] border border-[var(--line)] bg-[var(--surface-soft)] p-4">
                <p class="text-xs font-semibold uppercase tracking-[0.22em] text-[var(--muted)]">
                  Edit here when you need to
                </p>
                <ul class="mt-3 space-y-2 text-sm leading-6 text-[var(--ink)]">
                  <li :for={item <- page.edit_items}>• {item}</li>
                </ul>
              </div>

              <div class="rounded-[1.25rem] border border-[var(--line)] p-4">
                <p class="text-xs font-semibold uppercase tracking-[0.22em] text-[var(--muted)]">
                  Admin note
                </p>
                <p class="mt-3 text-sm leading-6 text-[var(--muted)]">{page.note}</p>
              </div>
            </div>
          </article>
        </div>
      </div>

      <div class="panel-shell">
        <p class="eyebrow">Diagnostics</p>
        <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
          If output, forecast, or revenue looks wrong
        </h2>

        <div class="mt-6 grid gap-4 md:grid-cols-3">
          <div
            :for={item <- @diagnostics}
            class="rounded-[1.5rem] border border-[var(--line)] bg-[var(--surface-soft)] p-4"
          >
            <p class="text-sm font-semibold uppercase tracking-[0.18em] text-[var(--muted)]">
              {item.title}
            </p>
            <p class="mt-3 text-sm leading-6 text-[var(--ink)]">{item.detail}</p>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp workflow_steps do
    [
      %{
        title: "Set crop rules first",
        detail:
          "Review cycle durations, expected yields, and price per unit in KES before changing anything else, because forecast and performance depend on those defaults."
      },
      %{
        title: "Keep greenhouse cycles current",
        detail:
          "When a greenhouse changes crop, update its active cycle dates, plant count, and variety so the dashboard and forecast use the right baseline."
      },
      %{
        title: "Enter harvests weekly",
        detail:
          "Harvest records should be updated every week ending date. Incorrect or missing weekly entries distort performance and future projections."
      },
      %{
        title: "Use analytics as a reading layer",
        detail:
          "Dashboard, performance, and forecast mostly explain the current state. If they look wrong, correct the upstream records instead of trying to treat the analytics screen as the source of truth."
      }
    ]
  end

  defp page_guides do
    [
      %{
        section: "Operations",
        title: "Dashboard",
        path: ~p"/dashboard",
        summary:
          "The dashboard is the fast read on what is harvesting now, what is in soil recovery, what output is expected this week, and which greenhouses need the next crop decision.",
        edit_items: [
          "Do not treat this as the source record. Use it to spot what needs attention.",
          "If a greenhouse status is wrong, edit the greenhouse crop cycle.",
          "If projected output looks off, check crop rules and harvest records."
        ],
        note:
          "Admins should use this page to triage operational issues, then navigate to Greenhouses, Harvest Records, or Crop Rules to make the actual correction."
      },
      %{
        section: "Operations",
        title: "Greenhouses",
        path: ~p"/greenhouses",
        summary:
          "This is the registry for greenhouse units and their current crop cycles. It controls which venture owns the unit and which cycle data feeds forecasting.",
        edit_items: [
          "Add or rename greenhouse units.",
          "Update venture assignment, sequence number, tank, and active status.",
          "Edit the current crop cycle dates, plant count, crop type, and variety when a cycle changes."
        ],
        note:
          "If the wrong crop or wrong cycle dates are stored here, dashboard status, expected output, and forecast recommendations will all be misleading."
      },
      %{
        section: "Execution",
        title: "Harvest Records",
        path: ~p"/harvest-records",
        summary:
          "This page stores weekly actual harvest values by greenhouse and week ending date. These rows feed the performance report and help tune short-range projections.",
        edit_items: [
          "Enter the actual weekly harvest for the correct week ending date.",
          "Correct any mistaken yield figure or note by editing the existing record.",
          "Use notes for quality issues, losses, or context that explains abnormal numbers."
        ],
        note:
          "If weekly actuals are missing or entered on the wrong greenhouse or wrong date, performance and revenue views will drift immediately."
      },
      %{
        section: "Analytics",
        title: "Performance",
        path: ~p"/performance",
        summary:
          "Performance compares actual harvests against expected output and derives revenue estimates from the crop rule pricing model.",
        edit_items: [
          "This is mainly a review page, not a source-editing page.",
          "If actual yield is wrong, edit Harvest Records.",
          "If expected yield or revenue is wrong, edit Crop Rules or Greenhouses."
        ],
        note:
          "Revenue here is only as reliable as the price-per-unit value in crop rules and the quality of the harvested data being compared."
      },
      %{
        section: "Analytics",
        title: "Forecast",
        path: ~p"/forecast",
        summary:
          "Forecast projects expected output over the next eight weeks and highlights peak weeks, next Saturday projections, and recommended next crops.",
        edit_items: [
          "Use this page to read forward, not to edit records directly.",
          "If the weekly forecast looks wrong, check greenhouse cycle dates first.",
          "If the baseline looks wrong, review crop rule yield models and price assumptions."
        ],
        note:
          "Forecast is downstream of crop rules, greenhouse cycles, and harvest history. Fix those pages first when this page disagrees with reality."
      },
      %{
        section: "Admin",
        title: "Crop Rules",
        path: ~p"/admin/crop-rules",
        summary:
          "Crop rules define the planning defaults for each crop: nursery time, days to harvest, harvest duration, expected yield, and price per unit in KES.",
        edit_items: [
          "Adjust durations when operating practice changes.",
          "Update expected yields when the baseline model changes.",
          "Update price per unit when revenue reporting should reflect a new market or contract rate."
        ],
        note:
          "This is the highest-impact admin screen. Small changes here can change forecasts, performance comparisons, and revenue estimates across multiple pages."
      },
      %{
        section: "Account",
        title: "Settings",
        path: ~p"/users/settings",
        summary:
          "Settings is for your own account details such as email and password. It does not control operational master data.",
        edit_items: [
          "Change your own login details.",
          "Confirm email changes when required.",
          "Use this page for account maintenance only."
        ],
        note:
          "If an operational number is wrong, settings is not the place to fix it. Use the guide above to identify the real source page."
      }
    ]
  end

  defp diagnostics do
    [
      %{
        title: "Wrong status or crop on dashboard",
        detail:
          "Check the greenhouse record and its current crop cycle dates, crop type, and variety. Status is derived from those fields."
      },
      %{
        title: "Wrong expected yield or forecast",
        detail:
          "Check the crop rule yield model first, then verify the greenhouse cycle size, plant count, and dates."
      },
      %{
        title: "Wrong revenue in KES",
        detail:
          "Check the crop rule price per unit in KES and the harvest record used for the underlying actual yield."
      }
    ]
  end
end
