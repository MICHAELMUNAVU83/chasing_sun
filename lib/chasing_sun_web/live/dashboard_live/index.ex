defmodule ChasingSunWeb.DashboardLive.Index do
  use ChasingSunWeb, :live_view

  alias ChasingSun.{Analytics, Operations}

  @impl true
  def mount(params, _session, socket) do
    venture_code = params["venture_code"] || "all"

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> load_dashboard(venture_code)}
  end

  @impl true
  def handle_event("filter", %{"venture_code" => venture_code}, socket) do
    {:noreply, load_dashboard(socket, venture_code)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-6">
      <div class="grid gap-6 lg:grid-cols-[minmax(0,1.8fr)_minmax(340px,1fr)]">
        <div class="panel-shell">
          <p class="eyebrow">Operations Pulse</p>
          <h1 class="page-title">ChasingSun greenhouse control room</h1>
          <p class="page-copy">
            Track live crop status, expected weekly output, and the next set of greenhouse actions from one place.
          </p>

          <div class="mt-6 flex flex-wrap gap-2">
            <button
              :for={venture <- filter_options(@ventures)}
              type="button"
              phx-click="filter"
              phx-value-venture_code={venture.code}
              class={filter_tab_class(@selected_venture, venture.code)}
            >
              {venture.label}
            </button>
          </div>

          <div class="mt-8 grid gap-4 grid-cols-2">
            <.summary_card
              title="Total units"
              value={@snapshot.metrics.total_units}
              hint="Greenhouses in the current filtered view"
            />
            <.summary_card
              title="Harvesting now"
              value={@snapshot.metrics.harvesting}
              hint="Units currently inside the harvest window"
              accent="yellow"
            />
            <.summary_card
              title="Soil turning"
              value={@snapshot.metrics.soil_turning}
              hint="Units inside post-harvest soil recovery"
              accent="ink"
            />
            <.summary_card
              title="Expected weekly output"
              value={format_quantity(@snapshot.metrics.expected_output)}
              hint="Projected yield from current active cycles"
            />
          </div>
        </div>

        <div class="panel-shell">
          <p class="eyebrow">Next Cycle Moves</p>
          <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
            Immediate crop recommendations
          </h2>

          <div class="mt-6 space-y-4">
            <div
              :for={recommendation <- @forecast.recommendations}
              class="rounded-[1.5rem] border border-[var(--line)] bg-[var(--surface-soft)] p-4"
            >
              <div class="flex items-start justify-between gap-4">
                <div>
                  <p class="text-base font-semibold text-[var(--ink)]">
                    {recommendation.greenhouse_name}
                  </p>
                  <p class="mt-1 text-sm text-[var(--muted)]">
                    Current crop: {recommendation.current_crop}
                  </p>
                </div>
                <.status_badge status="waiting" class="bg-[var(--brand-yellow)]/25 text-[var(--ink)]" />
              </div>

              <p class="mt-4 text-sm font-semibold text-[var(--brand-green-deep)]">
                Next crop: {recommendation.next_crop}
              </p>
              <p class="mt-1 text-sm text-[var(--muted)]">
                Harvest end: {format_date(recommendation.harvest_end_date)}
              </p>
            </div>

            <div
              :if={Enum.empty?(@forecast.recommendations)}
              class="rounded-[1.5rem] border border-dashed border-[var(--line)] p-5 text-sm text-[var(--muted)]"
            >
              Seed crop cycles to unlock next-crop guidance.
            </div>
          </div>
        </div>
      </div>

      <div class="grid gap-6 xl:grid-cols-[minmax(0,1.6fr)_minmax(320px,1fr)]">
        <div class="panel-shell">
          <div class="flex items-center justify-between gap-4">
            <div>
              <p class="eyebrow">Live Estate View</p>
              <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
                Greenhouse status board
              </h2>
            </div>
            <.link navigate={~p"/greenhouses"} class="action-link">Manage greenhouses</.link>
          </div>

          <div class="mt-6 overflow-x-auto">
            <table class="data-table">
              <thead>
                <tr>
                  <th>Greenhouse</th>
                  <th>Venture</th>
                  <th>Current crop</th>
                  <th>Status</th>
                  <th>Expected</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={row <- @greenhouse_rows}>
                  <td>
                    <p class="font-semibold text-[var(--ink)]">{row.name}</p>
                    <p class="mt-1 text-xs uppercase tracking-[0.18em] text-[var(--muted)]">
                      Unit {row.sequence_no}
                    </p>
                  </td>
                  <td>
                    <p class="font-semibold text-[var(--ink)]">{row.venture_name}</p>
                    <p class="mt-1 text-xs uppercase tracking-[0.18em] text-[var(--muted)]">
                      {row.venture_code}
                    </p>
                  </td>
                  <td>
                    <p>{row.crop_type || "No active cycle"}</p>
                    <p class="mt-1 text-xs text-[var(--muted)]">{row.crop_meta}</p>
                  </td>
                  <td>
                    <.status_badge status={row.status} />
                  </td>
                  <td>
                    <p class="font-semibold">{format_quantity(row.expected_output)}</p>
                    <p class="mt-1 text-xs text-[var(--muted)]">{row.output_hint}</p>
                  </td>
                </tr>
                <tr :if={Enum.empty?(@greenhouse_rows)}>
                  <td colspan="5" class="text-center text-sm text-[var(--muted)]">
                    No greenhouse records match the current filter.
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="space-y-6">
          <div class="panel-shell">
            <div class="flex items-center justify-between gap-4">
              <div>
                <p class="eyebrow">Projection</p>
                <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
                  Next Saturday outlook
                </h2>
              </div>
              <.link navigate={~p"/forecast"} class="action-link">View 8-week forecast</.link>
            </div>

            <div class="mt-6 space-y-4">
              <div
                :for={projection <- Enum.take(@forecast.projection, 4)}
                class="rounded-[1.5rem] border border-[var(--line)] p-4"
              >
                <div class="flex items-start justify-between gap-4">
                  <div>
                    <p class="font-semibold text-[var(--ink)]">{projection.greenhouse_name}</p>
                    <p class="mt-1 text-sm text-[var(--muted)]">{projection.crop_type}</p>
                  </div>
                  <p class="text-sm font-semibold text-[var(--brand-green-deep)]">
                    {format_quantity(projection.projected)} projected
                  </p>
                </div>
                <p class="mt-3 text-sm text-[var(--muted)]">
                  Expected baseline: {format_quantity(projection.expected)} on {format_date(
                    projection.week_ending_on
                  )}
                </p>
              </div>

              <div
                :if={Enum.empty?(@forecast.projection)}
                class="rounded-[1.5rem] border border-dashed border-[var(--line)] p-5 text-sm text-[var(--muted)]"
              >
                Harvest records are needed before projections can be calculated.
              </div>
            </div>
          </div>

          <div class="panel-shell">
            <p class="eyebrow">Audit Trail</p>
            <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
              Recent changes
            </h2>

            <div class="mt-6 space-y-4">
              <div
                :for={event <- @recent_events}
                class="rounded-[1.5rem] border border-[var(--line)] p-4"
              >
                <div class="flex items-start justify-between gap-4">
                  <div>
                    <p class="font-semibold text-[var(--ink)]">
                      {event.action |> String.replace("_", " ") |> String.capitalize()}
                    </p>
                    <p class="mt-1 text-sm text-[var(--muted)]">
                      {event.entity_type} #{event.entity_id || "-"}
                    </p>
                  </div>
                  <p class="text-xs uppercase tracking-[0.18em] text-[var(--muted)]">
                    {actor_label(event)}
                  </p>
                </div>
                <p class="mt-3 text-sm text-[var(--muted)]">{format_datetime(event.inserted_at)}</p>
              </div>

              <div
                :if={Enum.empty?(@recent_events)}
                class="rounded-[1.5rem] border border-dashed border-[var(--line)] p-5 text-sm text-[var(--muted)]"
              >
                Audit events will appear here after greenhouse, harvest, and rule changes.
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp load_dashboard(socket, venture_code) do
    filters = filters_for(venture_code)
    snapshot = Analytics.dashboard(filters)
    forecast = Analytics.forecast(filters)
    rules = Operations.list_crop_rules()

    assign(socket,
      selected_venture: venture_code,
      ventures: Operations.list_ventures(),
      snapshot: snapshot,
      forecast: forecast,
      greenhouse_rows: Enum.map(snapshot.greenhouses, &build_row(&1, rules)),
      recent_events: Operations.recent_audit_events(6)
    )
  end

  defp build_row(greenhouse, rules) do
    cycle = Operations.current_cycle(greenhouse)
    expected_output = if cycle, do: Operations.CropPlanner.expected_yield(cycle, rules), else: 0.0

    %{
      sequence_no: greenhouse.sequence_no,
      name: greenhouse.name,
      venture_name: greenhouse.venture.name,
      venture_code: greenhouse.venture.code,
      crop_type: cycle && cycle.crop_type,
      crop_meta: crop_meta(cycle),
      status: cycle && cycle.status_cache,
      expected_output: expected_output,
      output_hint: if(cycle, do: "Current cycle baseline", else: "Awaiting planting")
    }
  end

  defp crop_meta(nil), do: "No crop cycle assigned"

  defp crop_meta(cycle) do
    [cycle.variety, cycle.plant_count && "#{cycle.plant_count} plants"]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
    |> case do
      "" -> "Cycle registered"
      text -> text
    end
  end

  defp filter_options(ventures) do
    [
      %{code: "all", label: "All ventures"}
      | Enum.map(ventures, &%{code: &1.code, label: &1.name})
    ]
  end

  defp filter_tab_class(selected_venture, venture_code) do
    if selected_venture == venture_code do
      "filter-tab filter-tab-active"
    else
      "filter-tab"
    end
  end

  defp filters_for("all"), do: %{}
  defp filters_for(venture_code), do: %{venture_code: venture_code}

  defp format_quantity(value) when is_number(value),
    do: :erlang.float_to_binary(value * 1.0, decimals: 1)

  defp format_quantity(_value), do: "0.0"

  defp format_date(nil), do: "TBD"
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")

  defp format_datetime(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%d %b %Y %H:%M")
  defp format_datetime(_datetime), do: "Unknown"

  defp actor_label(event) do
    case event.actor_user do
      %{email: email} -> email
      _ -> "system"
    end
  end
end
