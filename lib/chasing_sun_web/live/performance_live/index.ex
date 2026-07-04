defmodule ChasingSunWeb.PerformanceLive.Index do
  use ChasingSunWeb, :live_view

  alias ChasingSun.Analytics
  alias ChasingSun.Operations

  @impl true
  def mount(params, _session, socket) do
    venture_code = params["venture_code"] || "all"

    {:ok,
     socket
     |> assign(:page_title, "Performance")
     |> load_report(venture_code, default_filters())}
  end

  @impl true
  def handle_event("filter", %{"venture_code" => venture_code}, socket) do
    {:noreply, load_report(socket, venture_code, socket.assigns.report_filters)}
  end

  def handle_event("change_mode", %{"mode" => mode}, socket) do
    filters = Map.put(socket.assigns.report_filters, "mode", mode)
    {:noreply, load_report(socket, socket.assigns.selected_venture, filters)}
  end

  def handle_event("change_filters", %{"report" => params}, socket) do
    {:noreply, load_report(socket, socket.assigns.selected_venture, params)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-8">
      <div class="panel-shell">
        <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
          <div>
            <h1 class="page-title">Performance</h1>
          </div>

          <div class="flex flex-wrap gap-2 print:hidden">
            <.link href={export_path(@selected_venture, @report.filters)} class="filter-tab">
              Download Excel
            </.link>
            <button type="button" onclick="window.print()" class="filter-tab">
              Print
            </button>
          </div>
        </div>

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

        <div class="mt-8 grid gap-4 md:grid-cols-3">
          <.summary_card title="Kg produced" value={format_quantity(@report.summary.total_actual)} />
          <.summary_card title="Revenue earned" value={format_kes(@report.summary.total_revenue)} />
          <.summary_card
            title="Variance to target"
            value={format_signed(@report.summary.total_variance)}
          />
        </div>
      </div>

      <div class="panel-shell">
        <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <h2 class="section-heading">Report filters</h2>
          <p class="text-sm text-[var(--muted)]">
            Showing
            <span class="font-semibold text-[var(--ink)]">{@report.filters.period_label}</span>
          </p>
        </div>

        <div class="mt-6 flex flex-wrap gap-2">
          <button
            type="button"
            phx-click="change_mode"
            phx-value-mode="week"
            class={mode_tab_class(@report.filters.mode, "week")}
          >
            Week
          </button>
          <button
            type="button"
            phx-click="change_mode"
            phx-value-mode="month"
            class={mode_tab_class(@report.filters.mode, "month")}
          >
            Month
          </button>
          <button
            type="button"
            phx-click="change_mode"
            phx-value-mode="season"
            class={mode_tab_class(@report.filters.mode, "season")}
          >
            Season
          </button>
        </div>

        <.form for={@filter_form} phx-change="change_filters" class="mt-6 grid gap-4 lg:grid-cols-4">
          <input type="hidden" name="report[mode]" value={@report.filters.mode} />

          <label class="block">
            <span class="text-xs font-medium uppercase tracking-wide text-zinc-400">
              Greenhouse
            </span>
            <select
              name="report[greenhouse_id]"
              class="mt-2 w-full rounded-xl border border-zinc-200 bg-white px-4 py-3 text-sm text-zinc-900"
            >
              <option value="">Select greenhouse</option>
              <option
                :for={greenhouse <- @report.greenhouse_options}
                value={greenhouse.id}
                selected={selected_option?(greenhouse.id, @report.filters.greenhouse_id)}
              >
                {greenhouse.name} {if greenhouse.size, do: "· #{greenhouse.size}", else: ""}
              </option>
            </select>
          </label>

          <label :if={@report.filters.mode == "week"} class="block">
            <span class="text-xs font-medium uppercase tracking-wide text-zinc-400">
              Week ending
            </span>
            <select
              name="report[week]"
              class="mt-2 w-full rounded-xl border border-zinc-200 bg-white px-4 py-3 text-sm text-zinc-900"
            >
              <option value="">Select week</option>
              <option
                :for={week <- @report.week_options}
                value={week.value}
                selected={selected_date_option?(week.date, @report.filters.selected_week)}
              >
                {week.label}
              </option>
            </select>
          </label>

          <label class="block">
            <span class="text-xs font-medium uppercase tracking-wide text-zinc-400">
              Estate month
            </span>
            <select
              name="report[month]"
              class="mt-2 w-full rounded-xl border border-zinc-200 bg-white px-4 py-3 text-sm text-zinc-900"
            >
              <option value="">Select month</option>
              <option
                :for={month <- @report.month_options}
                value={month.value}
                selected={month.value == @report.filters.selected_month}
              >
                {month.label}
              </option>
            </select>
          </label>

          <label :if={@report.filters.mode == "season"} class="block">
            <span class="text-xs font-medium uppercase tracking-wide text-zinc-400">
              Harvest season
            </span>
            <select
              name="report[season_id]"
              class="mt-2 w-full rounded-xl border border-zinc-200 bg-white px-4 py-3 text-sm text-zinc-900"
            >
              <option value="">Select season</option>
              <option
                :for={season <- @report.season_options}
                value={season.value}
                selected={season.value == @report.filters.selected_season_id}
              >
                {season.label}
              </option>
            </select>
          </label>
        </.form>
      </div>

      <div class="grid gap-6 xl:grid-cols-[minmax(0,2fr)_minmax(280px,1fr)]">
        <div class="panel-shell">
          <div class="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between">
            <div>
              <h2 class="section-heading">Greenhouse performance</h2>
              <p class="mt-1 text-sm text-[var(--muted)]">
                {@report.greenhouse_report.greenhouse_name || "No greenhouse selected"}
              </p>
            </div>
            <div class="text-sm text-[var(--muted)]">
              {@report.greenhouse_report.period_label}
            </div>
          </div>

          <div class="mt-6 overflow-x-auto">
            <table class="data-table">
              <thead>
                <tr>
                  <th>Greenhouse</th>
                  <th>Crop</th>
                  <th>Unit size</th>
                  <th>Period</th>
                  <th>Kg produced</th>
                  <th>Revenue earned</th>
                  <th>Variance</th>
                </tr>
              </thead>
              <tbody>
                <tr :if={@report.greenhouse_report.greenhouse_id}>
                  <td class="font-semibold">{@report.greenhouse_report.greenhouse_name}</td>
                  <td>{@report.greenhouse_report.crop_type || "No crop"}</td>
                  <td>{@report.greenhouse_report.unit_size || "-"}</td>
                  <td>{@report.greenhouse_report.period_label}</td>
                  <td>{format_quantity(@report.greenhouse_report.actual_yield)}</td>
                  <td>{format_kes(@report.greenhouse_report.revenue)}</td>
                  <td>
                    <p class={variance_class(@report.greenhouse_report.variance)}>
                      {format_signed(@report.greenhouse_report.variance)}
                    </p>
                    <p class="mt-1 text-xs text-[var(--muted)]">
                      {format_percent(@report.greenhouse_report.variance_pct)}
                    </p>
                  </td>
                </tr>
                <tr :if={!@report.greenhouse_report.greenhouse_id}>
                  <td colspan="7" class="text-center text-sm text-[var(--muted)]">
                    No greenhouse records are available for this filter.
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div class="mt-6 grid gap-4 md:grid-cols-3">
            <div class="rounded-xl border border-zinc-200 bg-white p-4">
              <p class="text-xs font-medium uppercase tracking-wide text-zinc-400">Harvested weeks</p>
              <p class="mt-2 text-2xl font-semibold text-zinc-900">
                {@report.greenhouse_report.harvested_weeks}
              </p>
            </div>
            <div class="rounded-xl border border-zinc-200 bg-white p-4">
              <p class="text-xs font-medium uppercase tracking-wide text-zinc-400">Expected yield</p>
              <p class="mt-2 text-2xl font-semibold text-zinc-900">
                {format_quantity(@report.greenhouse_report.expected_yield)}
              </p>
            </div>
            <div class="rounded-xl border border-zinc-200 bg-white p-4">
              <p class="text-xs font-medium uppercase tracking-wide text-zinc-400">
                Average per week
              </p>
              <p class="mt-2 text-2xl font-semibold text-zinc-900">
                {format_quantity(@report.greenhouse_report.average_per_week)}
              </p>
            </div>
          </div>
        </div>

        <div class="panel-shell">
          <h2 class="section-heading">Insights & recommendations</h2>

          <div class="mt-5 space-y-3">
            <div
              :for={insight <- @report.insights}
              class="rounded-xl border border-zinc-200 bg-white p-4 text-sm leading-6 text-zinc-700"
            >
              {insight}
            </div>
          </div>
        </div>
      </div>

      <div class="grid gap-6 xl:grid-cols-2">
        <div class="panel-shell">
          <h2 class="section-heading">Actual vs expected trend</h2>

          <div :if={@report.greenhouse_report.entries != []} class="mt-6 chart-frame">
            <canvas
              id="performance-trend-chart"
              phx-hook="ChartRenderer"
              data-chart={Jason.encode!(performance_chart(@report.greenhouse_report.entries))}
            >
            </canvas>
          </div>

          <div
            :if={@report.greenhouse_report.entries == []}
            class="mt-6 rounded-xl border border-dashed border-zinc-200 p-5 text-sm text-zinc-500"
          >
            No harvest entries are available for the current selection.
          </div>
        </div>

        <div class="panel-shell">
          <h2 class="section-heading">Period breakdown</h2>

          <div class="mt-6 overflow-x-auto">
            <table class="data-table">
              <thead>
                <tr>
                  <th>Week ending</th>
                  <th>Crop</th>
                  <th>Kg produced</th>
                  <th>Expected</th>
                  <th>Variance</th>
                  <th>Revenue</th>
                  <th>Crop age</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={entry <- @report.greenhouse_report.entries}>
                  <td>{format_date(entry.week_ending_on)}</td>
                  <td>{entry.crop_type || "-"}</td>
                  <td>{format_quantity(entry.actual_yield)}</td>
                  <td>{format_quantity(entry.expected_yield)}</td>
                  <td>
                    <p class={variance_class(entry.variance)}>{format_signed(entry.variance)}</p>
                    <p class="mt-1 text-xs text-[var(--muted)]">
                      {format_percent(entry.variance_pct)}
                    </p>
                  </td>
                  <td>{format_kes(entry.revenue)}</td>
                  <td>{format_weeks(entry.crop_age_weeks)}</td>
                </tr>
                <tr :if={Enum.empty?(@report.greenhouse_report.entries)}>
                  <td colspan="7" class="text-center text-sm text-[var(--muted)]">
                    No detailed harvest entries are available for this report.
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <div class="panel-shell">
        <div class="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between">
          <div>
            <h2 class="section-heading">Estate monthly rollup</h2>
            <p class="mt-1 text-sm text-[var(--muted)]">
              Performance by greenhouse for {@report.estate_month_label}
            </p>
          </div>
          <p class="text-sm text-[var(--muted)]">
            {length(@report.estate_rollup)} greenhouse{plural_suffix(length(@report.estate_rollup))}
          </p>
        </div>

        <div class="mt-6 overflow-x-auto">
          <table class="data-table">
            <thead>
              <tr>
                <th>Greenhouse</th>
                <th>Crop</th>
                <th>Unit size</th>
                <th>Kg produced</th>
                <th>Expected</th>
                <th>Variance</th>
                <th>Revenue</th>
                <th>Harvested weeks</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={row <- @report.estate_rollup}>
                <td class="font-semibold">{row.greenhouse_name}</td>
                <td>{row.crop_type || "No crop"}</td>
                <td>{row.unit_size || "-"}</td>
                <td>{format_quantity(row.actual_yield)}</td>
                <td>{format_quantity(row.expected_yield)}</td>
                <td>
                  <p class={variance_class(row.variance)}>{format_signed(row.variance)}</p>
                  <p class="mt-1 text-xs text-[var(--muted)]">{format_percent(row.variance_pct)}</p>
                </td>
                <td>{format_kes(row.revenue)}</td>
                <td>{row.harvested_weeks}</td>
              </tr>
              <tr :if={Enum.empty?(@report.estate_rollup)}>
                <td colspan="8" class="text-center text-sm text-[var(--muted)]">
                  No estate performance rows are available for this month.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>
    """
  end

  defp load_report(socket, venture_code, filters) do
    report = Analytics.performance_report(Map.put(filters, "venture_code", venture_code))

    assign(socket,
      selected_venture: venture_code,
      ventures: Operations.list_ventures(),
      report: report,
      report_filters: filter_values(report.filters),
      filter_form: filter_form(report.filters)
    )
  end

  defp default_filters do
    %{
      "mode" => "month",
      "greenhouse_id" => "",
      "week" => "",
      "month" => "",
      "season_id" => ""
    }
  end

  defp filter_form(filters) do
    to_form(filter_values(filters), as: :report)
  end

  defp filter_values(filters) do
    %{
      "mode" => filters.mode,
      "greenhouse_id" => stringify(filters.greenhouse_id),
      "week" => date_input_value(filters.selected_week),
      "month" => filters.selected_month || "",
      "season_id" => filters.selected_season_id || ""
    }
  end

  defp export_path(venture_code, filters) do
    params = %{
      venture_code: venture_code,
      mode: filters.mode,
      greenhouse_id: filters.greenhouse_id,
      week: date_input_value(filters.selected_week),
      month: filters.selected_month,
      season_id: filters.selected_season_id
    }

    ~p"/performance/export?#{params}"
  end

  defp filter_options(ventures) do
    [
      %{code: "all", label: "All ventures"}
      | Enum.map(ventures, &%{code: &1.code, label: &1.name})
    ]
  end

  defp filter_tab_class(selected_venture, venture_code) do
    if selected_venture == venture_code, do: "filter-tab filter-tab-active", else: "filter-tab"
  end

  defp mode_tab_class(selected_mode, mode) do
    if selected_mode == mode, do: "filter-tab filter-tab-active", else: "filter-tab"
  end

  defp selected_option?(option_value, selected_value),
    do: stringify(option_value) == stringify(selected_value)

  defp selected_date_option?(option_value, selected_value),
    do: date_input_value(option_value) == date_input_value(selected_value)

  defp stringify(nil), do: ""
  defp stringify(value), do: to_string(value)

  defp date_input_value(%Date{} = date), do: Date.to_iso8601(date)
  defp date_input_value(_date), do: ""

  defp variance_class(value) when value > 0, do: "font-semibold text-emerald-700"
  defp variance_class(value) when value < 0, do: "font-semibold text-rose-700"
  defp variance_class(_value), do: "font-semibold text-[var(--ink)]"

  defp format_quantity(value), do: format_number(value, decimals: 1)
  defp format_kes(value), do: ChasingSunWeb.FormatHelpers.format_currency(value, decimals: 1)

  defp format_signed(value) when is_number(value) and value > 0, do: "+#{format_quantity(value)}"
  defp format_signed(value) when is_number(value), do: format_quantity(value)
  defp format_signed(_value), do: "0.0"

  defp format_percent(value) when is_number(value),
    do: "#{:erlang.float_to_binary(value * 1.0, decimals: 1)}%"

  defp format_percent(_value), do: "0.0%"

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")
  defp format_date(_date), do: "-"

  defp format_weeks(nil), do: "-"
  defp format_weeks(value), do: "#{Float.round(value, 1)} weeks"

  defp plural_suffix(1), do: ""
  defp plural_suffix(_count), do: "s"

  defp performance_chart(entries) do
    sorted_entries = Enum.sort_by(entries, & &1.week_ending_on, Date)

    %{
      type: "line",
      valueFormat: "quantity",
      data: %{
        labels: Enum.map(sorted_entries, &format_date(&1.week_ending_on)),
        datasets: [
          %{
            label: "Actual yield",
            data: Enum.map(sorted_entries, &Float.round(&1.actual_yield, 1)),
            borderColor: "#3f722f",
            backgroundColor: "rgba(63, 114, 47, 0.12)",
            tension: 0.35,
            fill: true
          },
          %{
            label: "Expected yield",
            data: Enum.map(sorted_entries, &Float.round(&1.expected_yield, 1)),
            borderColor: "#18181b",
            backgroundColor: "rgba(24, 24, 27, 0.08)",
            tension: 0.35,
            fill: false
          }
        ]
      },
      options: %{
        scales: %{
          x: %{grid: %{display: false}, ticks: %{color: "#71717a"}},
          y: %{
            beginAtZero: true,
            grid: %{color: "rgba(24, 24, 27, 0.08)"},
            ticks: %{color: "#71717a"}
          }
        }
      }
    }
  end
end
