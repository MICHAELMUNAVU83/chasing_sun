defmodule ChasingSunWeb.DashboardLive.Index do
  use ChasingSunWeb, :live_view

  alias ChasingSun.{Analytics, Operations}
  alias ChasingSun.Accounts.Scope

  @impl true
  def mount(params, _session, socket) do
    venture_code = params["venture_code"] || "all"

    if connected?(socket) do
      Phoenix.PubSub.subscribe(ChasingSun.PubSub, Operations.operations_topic())
    end

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:selected_greenhouse_id, nil)
     |> load_dashboard(venture_code)}
  end

  @impl true
  def handle_event("filter", %{"venture_code" => venture_code}, socket) do
    {:noreply, load_dashboard(socket, venture_code)}
  end

  @impl true
  def handle_event("select_greenhouse", %{"greenhouse_id" => greenhouse_id}, socket) do
    {:noreply, assign(socket, :selected_greenhouse_id, parse_optional_int(greenhouse_id))}
  end

  @impl true
  def handle_info({:operations_refreshed, _today}, socket) do
    {:noreply, load_dashboard(socket, socket.assigns.selected_venture)}
  end

  def handle_info({:operation_notification, _notification}, socket) do
    {:noreply, load_dashboard(socket, socket.assigns.selected_venture)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-10">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <h1 class="page-title">Greenhouse control room</h1>

        <div class="flex flex-wrap gap-2">
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
      </div>

      <div
        :if={Scope.section_visible?(@current_user, "summary")}
        class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4"
      >
        <.summary_card title="Total units" value={@snapshot.metrics.total_units} />
        <.summary_card title="Harvesting now" value={@snapshot.metrics.harvesting} />
        <.summary_card title="Soil turning" value={@snapshot.metrics.soil_turning} />
        <.summary_card
          title="Expected weekly output"
          value={format_quantity(@snapshot.metrics.expected_output)}
        />
      </div>

      <div :if={Scope.section_visible?(@current_user, "status_board")} class="panel-shell">
            <div class="flex items-center justify-between gap-4">
              <h2 class="section-heading">Status board</h2>
              <.link navigate={~p"/greenhouses"} class="action-link">Manage greenhouses</.link>
            </div>

            <div class="mt-6 overflow-x-auto">
              <table class="data-table status-board-table">
                <colgroup>
                  <col class="w-14" />
                  <col class="min-w-[18rem]" />
                  <col class="min-w-[14rem]" />
                  <col class="min-w-[22rem]" />
                  <col class="w-32" />
                  <col class="min-w-[11rem]" />
                </colgroup>
                <thead>
                  <tr>
                    <th class="whitespace-nowrap">No</th>
                    <th>Greenhouse</th>
                    <th>Crop</th>
                    <th>Cycle overview</th>
                    <th class="whitespace-nowrap">Status</th>
                    <th>Latest harvest</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={row <- @greenhouse_rows}>
                    <td class="font-semibold">{row.sequence_no}</td>
                    <td>
                      <p class="font-semibold text-[var(--ink)]">{row.name}</p>
                      <p class="mt-1 text-xs uppercase tracking-[0.18em] text-[var(--muted)]">
                        {row.venture_name} · {String.upcase(row.venture_code)}
                      </p>
                      <p class="mt-2 text-xs text-[var(--muted)]">
                        Size {row.size || "-"} · Tank {row.tank || "-"}
                      </p>
                    </td>
                    <td>
                      <p>{row.crop_type || "No active cycle"}</p>
                      <p class="mt-1 text-xs text-[var(--muted)]">
                        {row.variety || "Variety pending"}
                      </p>
                      <p class="mt-2 text-xs text-[var(--muted)]">{row.crop_meta}</p>
                    </td>
                    <td>
                      <p class="font-medium text-[var(--ink)]">
                        {format_count(row.plant_count)} plants · {format_quantity(row.weekly_yield)}/wk
                      </p>
                      <p class="mt-1 text-xs text-[var(--muted)]">{row.output_hint}</p>
                      <p class="mt-2 text-xs text-[var(--muted)]">
                        Nursery {format_date(row.nursery_date)} · Transplant {format_date(
                          row.transplant_date
                        )}
                      </p>
                      <p class="mt-1 text-xs text-[var(--muted)]">
                        Harvest {format_date(row.harvest_start_date)} → {format_date(
                          row.harvest_end_date
                        )} · Soil {format_date(row.soil_recovery_end_date)}
                      </p>
                    </td>
                    <td class="align-middle">
                      <.status_badge status={row.status} />
                    </td>
                    <td>
                      <%= case row.latest_harvest do %>
                        <% nil -> %>
                          <p class="text-[var(--muted)]">No harvest data</p>
                        <% harvest -> %>
                          <p class="font-semibold">{format_quantity(harvest.actual_yield)}</p>
                          <p class="mt-1 text-xs text-[var(--muted)]">
                            {format_date(harvest.week_ending_on)}
                          </p>
                      <% end %>
                    </td>
                  </tr>
                  <tr :if={Enum.empty?(@greenhouse_rows)}>
                    <td colspan="6" class="text-center text-sm text-[var(--muted)]">
                      No greenhouse records match the current filter.
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <div :if={Scope.section_visible?(@current_user, "charts")} class="panel-shell">
            <h2 class="section-heading">Output, status, and projection graphs</h2>

            <div class="mt-6 grid gap-4 md:grid-cols-2">
              <div class="chart-shell">
                <p class="text-sm font-semibold text-[var(--ink)]">Expected output by greenhouse</p>
                <div class="chart-frame">
                  <canvas
                    id="dashboard-output-chart"
                    phx-hook="ChartRenderer"
                    data-chart={Jason.encode!(output_chart(@greenhouse_rows))}
                  >
                  </canvas>
                </div>
              </div>

              <div class="chart-shell">
                <p class="text-sm font-semibold text-[var(--ink)]">Expected output by venture</p>
                <div class="chart-frame">
                  <canvas
                    id="dashboard-venture-chart"
                    phx-hook="ChartRenderer"
                    data-chart={Jason.encode!(venture_output_chart(@greenhouse_rows))}
                  >
                  </canvas>
                </div>
              </div>

              <div class="chart-shell">
                <p class="text-sm font-semibold text-[var(--ink)]">
                  Next Saturday projection vs baseline
                </p>
                <div class="chart-frame">
                  <canvas
                    id="dashboard-projection-chart"
                    phx-hook="ChartRenderer"
                    data-chart={Jason.encode!(projection_chart(@forecast.projection))}
                  >
                  </canvas>
                </div>
              </div>

              <div class="chart-shell">
                <p class="text-sm font-semibold text-[var(--ink)]">Unit status mix</p>
                <div class="chart-frame">
                  <canvas
                    id="dashboard-status-chart"
                    phx-hook="ChartRenderer"
                    data-chart={Jason.encode!(status_chart(@snapshot.metrics))}
                  >
                  </canvas>
                </div>
              </div>
            </div>
          </div>

      <div class="grid gap-6 lg:grid-cols-2">
        <div :if={Scope.section_visible?(@current_user, "quick_view")} class="panel-shell">
          <h2 class="section-heading">Greenhouse quick view</h2>

            <form class="mt-6" phx-change="select_greenhouse">
              <label class="text-[11px] font-semibold uppercase tracking-[0.18em] text-[var(--muted)]">
                Greenhouse
              </label>
              <select
                name="greenhouse_id"
                class="mt-2 w-full rounded-2xl border border-[var(--line)] bg-white/80 px-4 py-3 text-sm font-semibold text-[var(--ink)] shadow-sm outline-none focus:border-[var(--brand-green)] focus:ring-2 focus:ring-[rgba(93,145,56,0.22)]"
              >
                <option value="" selected={is_nil(@selected_greenhouse_id)}>
                  Select a greenhouse…
                </option>
                <option
                  :for={row <- @greenhouse_rows}
                  value={row.greenhouse_id}
                  selected={@selected_greenhouse_id == row.greenhouse_id}
                >
                  {row.name}
                </option>
              </select>
            </form>

            <% selected = selected_greenhouse(@greenhouse_rows, @selected_greenhouse_id) %>

            <div
              :if={selected}
              class="mt-6 rounded-[1.75rem] border border-[var(--line)] bg-[var(--surface-soft)] p-4"
            >
              <div class="flex items-start justify-between gap-4">
                <div>
                  <p class="font-semibold text-[var(--ink)]">{selected.name}</p>
                  <p class="mt-1 text-xs uppercase tracking-[0.18em] text-[var(--muted)]">
                    {selected.venture_name} · {String.upcase(selected.venture_code)}
                  </p>
                </div>
                <.status_badge status={selected.status} class="shrink-0" />
              </div>

              <div class="mt-4 grid gap-3 sm:grid-cols-2">
                <.quick_field
                  label="Nursery date"
                  value={format_date(selected.nursery_date)}
                  class={nil}
                />
                <.quick_field
                  label="Transplant date"
                  value={format_date(selected.transplant_date)}
                  class={nil}
                />
                <.quick_field
                  label="Harvest start"
                  value={format_date(selected.harvest_start_date)}
                  class={nil}
                />
                <.quick_field
                  label="Harvest end"
                  value={format_date(selected.harvest_end_date)}
                  class={nil}
                />
                <.quick_field
                  label="Soil recovery start"
                  value={format_date(soil_recovery_start_date(selected))}
                  class={nil}
                />
                <.quick_field
                  label="Soil recovery end"
                  value={format_date(selected.soil_recovery_end_date)}
                  class={nil}
                />
                <.quick_field
                  label="Expected weekly yield"
                  value={format_quantity(selected.expected_output)}
                  class="sm:col-span-2"
                />
              </div>
            </div>

            <div
              :if={!selected}
              class="mt-6 rounded-[1.75rem] border border-dashed border-[var(--line)] p-5 text-sm text-[var(--muted)]"
            >
              Pick a greenhouse to preview its timeline.
            </div>
          </div>

          <div :if={Scope.section_visible?(@current_user, "recommendations")} class="panel-shell">
            <h2 class="section-heading">Immediate crop recommendations</h2>

            <div class="mt-6 grid gap-4 sm:grid-cols-2">
              <div class="rounded-[1.5rem] border border-[var(--line)] bg-[var(--surface-soft)] p-4">
                <p class="text-xs uppercase tracking-[0.18em] text-[var(--muted)]">
                  Active recommendations
                </p>
                <p class="mt-3 text-3xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
                  {length(@forecast.recommendations)}
                </p>
              </div>

              <div class="rounded-[1.5rem] border border-[var(--line)] bg-[var(--surface-soft)] p-4">
                <p class="text-xs uppercase tracking-[0.18em] text-[var(--muted)]">
                  Nursery in 7 days
                </p>
                <p class="mt-3 text-3xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
                  {due_soon_count(@forecast.recommendations, :nursery_date)}
                </p>
              </div>
            </div>

            <p
              :if={latest_generated_on(@forecast.recommendations)}
              class="mt-4 text-sm text-[var(--muted)]"
            >
              Latest planning refresh: {format_date(latest_generated_on(@forecast.recommendations))}
            </p>

            <.link navigate={~p"/recommendations"} class="action-link mt-6 inline-flex">
              Open recommendations page
            </.link>
          </div>
        </div>

        <div class="grid gap-6 lg:grid-cols-2">
          <div :if={Scope.section_visible?(@current_user, "notifications")} class="panel-shell">
            <h2 class="section-heading">Daily notifications</h2>

            <div class="mt-6 space-y-4">
              <div
                :for={notification <- @notifications}
                class="rounded-[1.5rem] border border-[var(--line)] bg-[var(--surface-soft)] p-4"
              >
                <div class="flex items-start justify-between gap-4">
                  <div>
                    <p class="font-semibold text-[var(--ink)]">{notification.greenhouse.name}</p>
                    <p class="mt-1 text-sm text-[var(--muted)]">{notification.message}</p>
                  </div>
                  <p class="text-xs uppercase tracking-[0.18em] text-[var(--muted)]">
                    {format_date(notification.notify_on)}
                  </p>
                </div>
              </div>

              <div
                :if={Enum.empty?(@notifications)}
                class="rounded-[1.5rem] border border-dashed border-[var(--line)] p-5 text-sm text-[var(--muted)]"
              >
                Notifications will appear here when nursery windows open or rotations are triggered.
              </div>
            </div>
          </div>

          <div :if={Scope.section_visible?(@current_user, "projections")} class="panel-shell">
            <div class="flex items-center justify-between gap-4">
              <h2 class="section-heading">Next Saturday outlook</h2>
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
        </div>

        <div :if={ChasingSunWeb.UserAuth.can?(@current_user, :view_operations)} class="panel-shell">
          <h2 class="section-heading">Recent changes</h2>

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
    </section>
    """
  end

  defp load_dashboard(socket, venture_code) do
    allowed_codes = Scope.visible_venture_codes(socket.assigns[:current_user])
    ventures = visible_ventures(allowed_codes)
    venture_code = sanitize_venture_code(venture_code, allowed_codes)
    filters = filters_for(venture_code, allowed_codes)
    snapshot = Analytics.dashboard(filters)
    forecast = Analytics.forecast(filters)
    rules = Operations.list_crop_rules()
    greenhouse_rows = Enum.map(snapshot.greenhouses, &build_row(&1, rules))

    selected_greenhouse_id =
      ensure_selected_greenhouse_id(socket.assigns[:selected_greenhouse_id], greenhouse_rows)

    assign(socket,
      selected_venture: venture_code,
      ventures: ventures,
      snapshot: snapshot,
      forecast: forecast,
      greenhouse_rows: greenhouse_rows,
      selected_greenhouse_id: selected_greenhouse_id,
      notifications: Operations.recent_operation_notifications(6, filters),
      recent_events: Operations.recent_audit_events(6)
    )
  end

  defp build_row(greenhouse, rules) do
    cycle = Operations.current_cycle(greenhouse)
    expected_output = if cycle, do: Operations.CropPlanner.expected_yield(cycle, rules), else: 0.0
    latest_harvest = List.first(greenhouse.harvest_records)
    status = cycle && cycle.status_cache

    %{
      greenhouse_id: greenhouse.id,
      sequence_no: greenhouse.sequence_no,
      name: greenhouse.name,
      size: greenhouse.size,
      tank: greenhouse.tank,
      venture_name: greenhouse.venture.name,
      venture_code: greenhouse.venture.code,
      crop_type: cycle && cycle.crop_type,
      variety: cycle && cycle.variety,
      plant_count: cycle && cycle.plant_count,
      nursery_date: cycle && cycle.nursery_date,
      transplant_date: cycle && cycle.transplant_date,
      harvest_start_date: cycle && cycle.harvest_start_date,
      harvest_end_date: cycle && cycle.harvest_end_date,
      soil_recovery_end_date: cycle && cycle.soil_recovery_end_date,
      crop_meta: crop_meta(cycle),
      status: status,
      expected_output: expected_output,
      weekly_yield: weekly_yield(status, expected_output),
      output_hint: output_hint(status, cycle),
      latest_harvest: latest_harvest
    }
  end

  defp crop_meta(nil), do: "No cycle registered yet"

  defp crop_meta(cycle) do
    cond do
      cycle.harvest_start_date && cycle.harvest_end_date ->
        "Harvest window #{format_date(cycle.harvest_start_date)} to #{format_date(cycle.harvest_end_date)}"

      cycle.transplant_date ->
        "Transplanted #{format_date(cycle.transplant_date)}"

      cycle.nursery_date ->
        "Nursery started #{format_date(cycle.nursery_date)}"

      true ->
        "Cycle registered"
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

  # No guest venture restriction: behave as before.
  defp filters_for(venture_code, nil), do: filters_for(venture_code)
  # Guest restricted to a set of ventures: a specific (allowed) selection wins,
  # otherwise constrain "all" to the allowed set so nothing else leaks in.
  defp filters_for("all", allowed_codes), do: %{venture_codes: allowed_codes}

  defp filters_for(venture_code, allowed_codes) do
    if venture_code in allowed_codes do
      %{venture_code: venture_code}
    else
      %{venture_codes: allowed_codes}
    end
  end

  defp filters_for("all"), do: %{}
  defp filters_for(venture_code), do: %{venture_code: venture_code}

  defp visible_ventures(nil), do: Operations.list_ventures()

  defp visible_ventures(allowed_codes) do
    Enum.filter(Operations.list_ventures(), &(&1.code in allowed_codes))
  end

  # Keep guests from forcing an out-of-scope venture via the URL.
  defp sanitize_venture_code(venture_code, nil), do: venture_code
  defp sanitize_venture_code("all", _allowed_codes), do: "all"

  defp sanitize_venture_code(venture_code, allowed_codes) do
    if venture_code in allowed_codes, do: venture_code, else: "all"
  end

  defp format_quantity(value), do: format_number(value, decimals: 1)
  defp format_count(nil), do: "-"
  defp format_count(value), do: format_number(value, decimals: 0)

  defp format_date(nil), do: "TBD"
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")

  defp format_datetime(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%d %b %Y %H:%M")
  defp format_datetime(_datetime), do: "Unknown"

  defp quick_field(assigns) do
    assigns = Map.put_new(assigns, :class, nil)

    ~H"""
    <div class={[
      "rounded-2xl border border-[var(--line)] bg-white/70 px-3 py-2",
      @class
    ]}>
      <p class="text-[11px] font-semibold uppercase tracking-[0.18em] text-[var(--muted)]">
        {@label}
      </p>
      <p class="mt-1 text-sm font-semibold text-[var(--ink)]">
        {@value}
      </p>
    </div>
    """
  end

  defp parse_optional_int(nil), do: nil

  defp parse_optional_int(value) when is_binary(value) do
    value = String.trim(value)

    case value do
      "" -> nil
      _ -> String.to_integer(value)
    end
  rescue
    ArgumentError -> nil
  end

  defp parse_optional_int(value) when is_integer(value), do: value
  defp parse_optional_int(_value), do: nil

  defp selected_greenhouse(rows, selected_greenhouse_id) when is_list(rows) do
    Enum.find(rows, fn row -> row.greenhouse_id == selected_greenhouse_id end)
  end

  defp ensure_selected_greenhouse_id(selected_greenhouse_id, rows) when is_list(rows) do
    cond do
      Enum.empty?(rows) ->
        nil

      is_integer(selected_greenhouse_id) and
          Enum.any?(rows, fn row -> row.greenhouse_id == selected_greenhouse_id end) ->
        selected_greenhouse_id

      true ->
        List.first(rows).greenhouse_id
    end
  end

  defp soil_recovery_start_date(%{soil_recovery_end_date: %Date{} = soil_recovery_end_date}),
    do: Date.add(soil_recovery_end_date, -Operations.CropPlanner.soil_recovery_days())

  defp soil_recovery_start_date(%{harvest_end_date: %Date{} = harvest_end_date}),
    do: harvest_end_date

  defp soil_recovery_start_date(_row), do: nil

  defp due_soon_count(recommendations, field) do
    today = Date.utc_today()
    deadline = Date.add(today, 7)

    Enum.count(recommendations, fn recommendation ->
      case Map.get(recommendation, field) do
        %Date{} = date -> Date.compare(date, today) != :lt and Date.compare(date, deadline) != :gt
        _ -> false
      end
    end)
  end

  defp latest_generated_on([]), do: nil

  defp latest_generated_on(recommendations),
    do: Enum.max_by(recommendations, & &1.generated_on).generated_on

  defp actor_label(event) do
    case event.actor_user do
      %{email: email} -> email
      _ -> "system"
    end
  end

  defp weekly_yield(:harvesting, expected_output), do: expected_output
  defp weekly_yield(_, _expected_output), do: 0.0

  defp output_hint(_status, nil), do: "Awaiting planting"
  defp output_hint(:harvesting, _cycle), do: "Current weekly baseline"
  defp output_hint(:soil_turning, _cycle), do: "Paused during soil recovery"
  defp output_hint(:waiting, _cycle), do: "Starts once harvest opens"

  defp output_chart(rows) do
    sorted_rows = Enum.sort_by(rows, & &1.expected_output, :desc)

    %{
      type: "bar",
      valueFormat: "quantity",
      data: %{
        labels: Enum.map(sorted_rows, & &1.name),
        datasets: [
          %{
            label: "Expected weekly output",
            data: Enum.map(sorted_rows, &Float.round(&1.expected_output, 1)),
            backgroundColor: "rgba(93, 145, 56, 0.82)",
            borderRadius: 12
          }
        ]
      },
      options: %{
        plugins: %{legend: %{display: false}},
        scales: %{
          x: %{grid: %{display: false}, ticks: %{color: "#5f6d4f"}},
          y: %{
            beginAtZero: true,
            grid: %{color: "rgba(76, 99, 46, 0.12)"},
            ticks: %{color: "#5f6d4f"}
          }
        }
      }
    }
  end

  defp status_chart(metrics) do
    waiting = max(metrics.total_units - metrics.harvesting - metrics.soil_turning, 0)

    %{
      type: "doughnut",
      valueFormat: "integer",
      data: %{
        labels: ["Harvesting", "Soil turning", "Waiting"],
        datasets: [
          %{
            data: [metrics.harvesting, metrics.soil_turning, waiting],
            backgroundColor: ["#5d9138", "#f3d74f", "#d8e3c3"],
            borderColor: ["#ffffff", "#ffffff", "#ffffff"],
            borderWidth: 3
          }
        ]
      },
      options: %{
        cutout: "62%",
        plugins: %{legend: %{position: "bottom"}}
      }
    }
  end

  defp venture_output_chart(rows) do
    venture_rows =
      rows
      |> Enum.group_by(& &1.venture_name)
      |> Enum.map(fn {venture_name, venture_rows} ->
        %{
          venture_name: venture_name,
          expected_output: Enum.reduce(venture_rows, 0.0, &(&1.expected_output + &2))
        }
      end)
      |> Enum.sort_by(& &1.expected_output, :desc)

    %{
      type: "bar",
      valueFormat: "quantity",
      data: %{
        labels: Enum.map(venture_rows, & &1.venture_name),
        datasets: [
          %{
            label: "Expected weekly output",
            data: Enum.map(venture_rows, &Float.round(&1.expected_output, 1)),
            backgroundColor: [
              "rgba(93, 145, 56, 0.86)",
              "rgba(243, 215, 79, 0.78)",
              "rgba(63, 114, 47, 0.72)",
              "rgba(184, 204, 150, 0.92)"
            ],
            borderRadius: 12
          }
        ]
      },
      options: %{
        plugins: %{legend: %{display: false}},
        scales: %{
          x: %{grid: %{display: false}, ticks: %{color: "#5f6d4f"}},
          y: %{
            beginAtZero: true,
            grid: %{color: "rgba(76, 99, 46, 0.12)"},
            ticks: %{color: "#5f6d4f"}
          }
        }
      }
    }
  end

  defp projection_chart(projections) do
    visible_projections = Enum.take(projections, 6)

    %{
      type: "bar",
      valueFormat: "quantity",
      data: %{
        labels: Enum.map(visible_projections, & &1.greenhouse_name),
        datasets: [
          %{
            label: "Expected baseline",
            data: Enum.map(visible_projections, &Float.round(&1.expected, 1)),
            backgroundColor: "rgba(243, 215, 79, 0.65)",
            borderRadius: 10
          },
          %{
            label: "Projected output",
            data: Enum.map(visible_projections, &Float.round(&1.projected, 1)),
            backgroundColor: "rgba(93, 145, 56, 0.82)",
            borderRadius: 10
          }
        ]
      },
      options: %{
        scales: %{
          x: %{grid: %{display: false}, ticks: %{color: "#5f6d4f"}},
          y: %{
            beginAtZero: true,
            grid: %{color: "rgba(76, 99, 46, 0.12)"},
            ticks: %{color: "#5f6d4f"}
          }
        }
      }
    }
  end
end
