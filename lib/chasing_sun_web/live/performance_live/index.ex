defmodule ChasingSunWeb.PerformanceLive.Index do
  use ChasingSunWeb, :live_view

  alias ChasingSun.Analytics
  alias ChasingSun.Operations

  @impl true
  def mount(params, _session, socket) do
    venture_code = params["venture_code"] || "all"
    history_filter = default_history_filter()

    {:ok,
     socket
     |> assign(:page_title, "Performance")
     |> load_report(venture_code, history_filter)}
  end

  @impl true
  def handle_event("filter", %{"venture_code" => venture_code}, socket) do
    {:noreply, load_report(socket, venture_code, socket.assigns.history_filter)}
  end

  def handle_event("history_preset", %{"preset" => preset}, socket) do
    {:noreply, load_report(socket, socket.assigns.selected_venture, history_preset(preset))}
  end

  def handle_event("history_range", %{"history" => params}, socket) do
    {:noreply, load_report(socket, socket.assigns.selected_venture, history_range(params))}
  end

  def handle_event("select_week", %{"date" => date}, socket) do
    {:noreply, load_report(socket, socket.assigns.selected_venture, history_week(date))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-6">
      <div class="panel-shell">
        <p class="eyebrow">Performance Analytics</p>
        <h1 class="page-title">Expected vs actual harvest performance</h1>
        <p class="page-copy">
          Compare actual weekly output to crop-rule expectations and surface where yield is over or under baseline.
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

        <div class="mt-8 grid gap-4 md:grid-cols-3">
          <.summary_card
            title="Actual yield"
            value={format_quantity(@report.summary.total_actual)}
            hint="Summed from visible harvest records"
          />
          <.summary_card
            title="Expected yield"
            value={format_quantity(@report.summary.total_expected)}
            hint="Rule-based baseline for the same records"
            accent="yellow"
          />
          <.summary_card
            title="Revenue estimate"
            value={format_kes(@report.summary.total_revenue)}
            hint="Derived from crop rule pricing"
            accent="ink"
          />
        </div>
      </div>

      <div class="panel-shell">
        <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
          <div>
            <p class="eyebrow">Harvest History Explorer</p>
            <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
              Past harvest records by Saturday
            </h2>
            <p class="mt-3 max-w-3xl text-sm leading-6 text-[var(--muted)]">
              Select one Saturday or choose a date range to see total harvest and the exact units
              that removed fruits during that period.
            </p>
          </div>

          <div class="rounded-[1.5rem] border border-[var(--line)] bg-[var(--surface-soft)] px-4 py-3 text-sm text-[var(--muted)]">
            Showing <span class="font-semibold text-[var(--ink)]">{@history_filter.label}</span>
          </div>
        </div>

        <div class="mt-6 flex flex-wrap gap-2">
          <button
            type="button"
            phx-click="history_preset"
            phx-value-preset="all"
            class={history_preset_class(@history_filter, "all")}
          >
            All records
          </button>
          <button
            type="button"
            phx-click="history_preset"
            phx-value-preset="past_2_weeks"
            class={history_preset_class(@history_filter, "past_2_weeks")}
          >
            Past 2 weeks
          </button>
          <button
            type="button"
            phx-click="history_preset"
            phx-value-preset="last_8_weeks"
            class={history_preset_class(@history_filter, "last_8_weeks")}
          >
            Last 8 weeks
          </button>
          <button
            type="button"
            phx-click="history_preset"
            phx-value-preset="mar_may"
            class={history_preset_class(@history_filter, "mar_may")}
          >
            Mar-May
          </button>
        </div>

        <.form
          for={@history_form}
          phx-submit="history_range"
          class="mt-5 grid gap-4 md:grid-cols-[1fr_1fr_auto]"
        >
          <label class="block">
            <span class="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--muted)]">
              Start date
            </span>
            <input
              type="date"
              name="history[start_date]"
              value={@history_form[:start_date].value}
              class="mt-2 w-full rounded-2xl border border-[var(--line)] bg-white px-4 py-3 text-sm text-[var(--ink)]"
            />
          </label>
          <label class="block">
            <span class="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--muted)]">
              End date
            </span>
            <input
              type="date"
              name="history[end_date]"
              value={@history_form[:end_date].value}
              class="mt-2 w-full rounded-2xl border border-[var(--line)] bg-white px-4 py-3 text-sm text-[var(--ink)]"
            />
          </label>
          <button
            type="submit"
            class="self-end rounded-full bg-[var(--brand-green)] px-5 py-3 text-sm font-semibold text-white transition hover:bg-[var(--brand-green-deep)]"
          >
            Apply range
          </button>
        </.form>

        <div class="mt-6 grid gap-4 md:grid-cols-3">
          <div class="rounded-[1.5rem] border border-[var(--line)] bg-white/70 p-4">
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--muted)]">
              Period harvest
            </p>
            <p class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
              {format_quantity(@report.summary.total_actual)}
            </p>
          </div>
          <div class="rounded-[1.5rem] border border-[var(--line)] bg-white/70 p-4">
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--muted)]">
              Units removing fruits
            </p>
            <p class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
              {@history_summary.unit_count}
            </p>
            <p class="mt-2 text-sm text-[var(--muted)]">
              {unit_names(@history_summary.unit_names)}
            </p>
          </div>
          <div class="rounded-[1.5rem] border border-[var(--line)] bg-white/70 p-4">
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--muted)]">
              Harvest Saturdays
            </p>
            <p class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
              {@history_summary.week_count}
            </p>
          </div>
        </div>

        <div
          :if={not Enum.empty?(@history_summary.unit_breakdown)}
          class="mt-6 rounded-[1.75rem] border border-[var(--line)] bg-white/70 p-4"
        >
          <div class="flex items-center justify-between gap-4">
            <p class="text-sm font-semibold text-[var(--ink)]">Yield by greenhouse (selected view)</p>
            <p class="text-xs uppercase tracking-[0.18em] text-[var(--muted)]">
              Top {min(length(@history_summary.unit_breakdown), 10)}
            </p>
          </div>

          <div class="mt-4 grid gap-3 md:grid-cols-2">
            <div
              :for={unit <- Enum.take(@history_summary.unit_breakdown, 10)}
              class="flex items-start justify-between gap-4 rounded-[1.25rem] border border-[var(--line)] bg-white/60 px-4 py-3"
            >
              <div>
                <p class="font-semibold text-[var(--ink)]">{unit.greenhouse_name}</p>
                <p class="mt-1 text-xs text-[var(--muted)]">
                  {unit.week_count} Saturday{plural_suffix(unit.week_count)} in selection
                </p>
              </div>
              <p class="text-sm font-semibold text-[var(--brand-green-deep)]">
                {format_quantity(unit.actual_yield)}
              </p>
            </div>
          </div>
        </div>

        <div class="mt-6">
          <div class="flex items-center justify-between gap-4">
            <p class="text-sm font-semibold text-[var(--ink)]">Clickable Saturday calendar</p>
            <p class="text-xs uppercase tracking-[0.18em] text-[var(--muted)]">
              {length(@history_groups)} dates
            </p>
          </div>

          <div class="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-3">
            <button
              :for={group <- @history_groups}
              type="button"
              phx-click="select_week"
              phx-value-date={Date.to_iso8601(group.week_ending_on)}
              class={history_week_class(@history_filter, group.week_ending_on)}
            >
              <div class="flex items-start justify-between gap-3">
                <div class="text-left">
                  <p class="font-semibold text-[var(--ink)]">{format_date(group.week_ending_on)}</p>
                  <p class="mt-1 text-xs text-[var(--muted)]">
                    {group.unit_count} unit{plural_suffix(group.unit_count)} removed fruits
                  </p>
                </div>
                <p class="text-sm font-semibold text-[var(--brand-green-deep)]">
                  {format_quantity(group.actual_yield)}
                </p>
              </div>
              <p class="mt-3 text-left text-xs leading-5 text-[var(--muted)]">
                {unit_names(group.unit_names)}
              </p>
            </button>
          </div>

          <div
            :if={Enum.empty?(@history_groups)}
            class="mt-4 rounded-[1.5rem] border border-dashed border-[var(--line)] p-5 text-sm text-[var(--muted)]"
          >
            No Saturday harvest records are available for this venture and date selection.
          </div>
        </div>
      </div>

      <div class="panel-shell">
        <p class="eyebrow">Detailed Breakdown</p>
        <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
          Weekly performance table
        </h2>

        <div class="mt-6 chart-shell">
          <p class="text-sm font-semibold text-[var(--ink)]">Actual vs expected trend</p>
          <div class="chart-frame">
            <canvas
              id="performance-trend-chart"
              phx-hook="ChartRenderer"
              data-chart={Jason.encode!(performance_chart(@report.rows))}
            >
            </canvas>
          </div>
        </div>

        <div class="mt-6 overflow-x-auto">
          <table class="data-table">
            <thead>
              <tr>
                <th>Week</th>
                <th>Greenhouse</th>
                <th>Crop</th>
                <th>Actual</th>
                <th>Expected</th>
                <th>Variance</th>
                <th>Revenue</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={row <- @report.rows}>
                <td>{format_date(row.week_ending_on)}</td>
                <td>
                  <p class="font-semibold text-[var(--ink)]">{row.greenhouse_name}</p>
                  <p class="mt-1 text-xs text-[var(--muted)]">{row.venture_code}</p>
                </td>
                <td>{row.crop_type || "No crop"}</td>
                <td>{format_quantity(row.actual_yield)}</td>
                <td>{format_quantity(row.expected_yield)}</td>
                <td>
                  <p class={variance_class(row.variance)}>{format_signed(row.variance)}</p>
                  <p class="mt-1 text-xs text-[var(--muted)]">{format_percent(row.variance_pct)}</p>
                </td>
                <td>{format_kes(row.revenue)}</td>
              </tr>
              <tr :if={Enum.empty?(@report.rows)}>
                <td colspan="7" class="text-center text-sm text-[var(--muted)]">
                  No harvest records exist for the current filter.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>
    """
  end

  defp load_report(socket, venture_code, history_filter) do
    filters = filters_for(venture_code)

    report =
      Analytics.performance_report(Map.merge(filters, history_filter_params(history_filter)))

    history_groups = history_groups_for(filters, history_filter)

    assign(socket,
      selected_venture: venture_code,
      ventures: Operations.list_ventures(),
      report: report,
      history_filter: history_filter,
      history_form: history_form(history_filter),
      history_groups: history_groups,
      history_summary: history_summary(report.rows)
    )
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

  defp filters_for("all"), do: %{}
  defp filters_for(venture_code), do: %{venture_code: venture_code}

  defp default_history_filter do
    %{
      preset: "all",
      start_date: nil,
      end_date: nil,
      selected_week: nil,
      label: "all harvest records"
    }
  end

  defp history_preset("past_2_weeks") do
    today = Date.utc_today()
    start_date = Date.add(today, -14)

    %{
      preset: "past_2_weeks",
      start_date: start_date,
      end_date: today,
      selected_week: nil,
      label: "past 2 weeks"
    }
  end

  defp history_preset("last_8_weeks") do
    today = Date.utc_today()
    start_date = Date.add(today, -56)

    %{
      preset: "last_8_weeks",
      start_date: start_date,
      end_date: today,
      selected_week: nil,
      label: "last 8 weeks"
    }
  end

  defp history_preset("mar_may") do
    year = Date.utc_today().year
    {:ok, start_date} = Date.new(year, 3, 1)
    {:ok, end_date} = Date.new(year, 5, 31)

    %{
      preset: "mar_may",
      start_date: start_date,
      end_date: end_date,
      selected_week: nil,
      label: "Mar-May #{year}"
    }
  end

  defp history_preset(_preset), do: default_history_filter()

  defp history_range(params) do
    start_date = parse_date(params["start_date"])
    end_date = parse_date(params["end_date"])

    {start_date, end_date} =
      case {start_date, end_date} do
        {%Date{} = start_date, %Date{} = end_date} ->
          if Date.compare(start_date, end_date) == :gt,
            do: {end_date, start_date},
            else: {start_date, end_date}

        dates ->
          dates
      end

    %{
      preset: "custom",
      start_date: start_date,
      end_date: end_date,
      selected_week: nil,
      label: range_label(start_date, end_date)
    }
  end

  defp history_week(date) do
    selected_week = parse_date(date)

    %{
      preset: "week",
      start_date: nil,
      end_date: nil,
      selected_week: selected_week,
      label: "harvest on #{format_date(selected_week)}"
    }
  end

  defp history_filter_params(%{selected_week: %Date{} = selected_week}) do
    %{week_ending_on: selected_week}
  end

  defp history_filter_params(%{start_date: start_date, end_date: end_date}) do
    %{}
    |> maybe_put_date(:start_date, start_date)
    |> maybe_put_date(:end_date, end_date)
  end

  defp history_calendar_params(%{preset: "week"}), do: %{}
  defp history_calendar_params(history_filter), do: history_filter_params(history_filter)

  defp history_groups_for(filters, history_filter) do
    filters
    |> Map.merge(history_calendar_params(history_filter))
    |> Analytics.performance_report()
    |> Map.fetch!(:rows)
    |> history_groups()
  end

  defp history_groups(rows) do
    rows
    |> Enum.group_by(& &1.week_ending_on)
    |> Enum.map(fn {week_ending_on, week_rows} ->
      unit_names =
        week_rows
        |> Enum.map(& &1.greenhouse_name)
        |> Enum.uniq()
        |> Enum.sort()

      %{
        week_ending_on: week_ending_on,
        actual_yield: Enum.reduce(week_rows, 0.0, &(&1.actual_yield + &2)),
        unit_count: length(unit_names),
        unit_names: unit_names
      }
    end)
    |> Enum.sort_by(& &1.week_ending_on, {:desc, Date})
  end

  defp history_summary(rows) do
    unit_groups = Enum.group_by(rows, & &1.greenhouse_name)

    unit_names =
      unit_groups
      |> Map.keys()
      |> Enum.sort()

    unit_breakdown =
      unit_groups
      |> Enum.map(fn {greenhouse_name, unit_rows} ->
        %{
          greenhouse_name: greenhouse_name,
          actual_yield: Enum.reduce(unit_rows, 0.0, &(&1.actual_yield + &2)),
          week_count: unit_rows |> Enum.map(& &1.week_ending_on) |> Enum.uniq() |> length()
        }
      end)
      |> Enum.sort_by(& &1.actual_yield, :desc)

    %{
      unit_count: length(unit_names),
      unit_names: unit_names,
      week_count: rows |> Enum.map(& &1.week_ending_on) |> Enum.uniq() |> length(),
      unit_breakdown: unit_breakdown
    }
  end

  defp history_form(history_filter) do
    to_form(
      %{
        "start_date" => date_input_value(history_filter.start_date),
        "end_date" => date_input_value(history_filter.end_date)
      },
      as: :history
    )
  end

  defp history_preset_class(%{preset: preset}, preset), do: "filter-tab filter-tab-active"
  defp history_preset_class(_history_filter, _preset), do: "filter-tab"

  defp history_week_class(%{selected_week: selected_week}, week_ending_on)
       when selected_week == week_ending_on do
    "rounded-[1.5rem] border border-[var(--brand-green)] bg-[var(--surface-soft)] p-4 transition"
  end

  defp history_week_class(_history_filter, _week_ending_on) do
    "rounded-[1.5rem] border border-[var(--line)] bg-white/70 p-4 transition hover:border-[var(--brand-green)] hover:bg-[var(--surface-soft)]"
  end

  defp unit_names([]), do: "No units in this selection"
  defp unit_names(names), do: Enum.join(names, ", ")

  defp range_label(nil, nil), do: "all harvest records"
  defp range_label(%Date{} = start_date, nil), do: "from #{format_date(start_date)}"
  defp range_label(nil, %Date{} = end_date), do: "through #{format_date(end_date)}"

  defp range_label(%Date{} = start_date, %Date{} = end_date) do
    "#{format_date(start_date)} to #{format_date(end_date)}"
  end

  defp maybe_put_date(params, _key, nil), do: params
  defp maybe_put_date(params, key, %Date{} = date), do: Map.put(params, key, date)

  defp date_input_value(%Date{} = date), do: Date.to_iso8601(date)
  defp date_input_value(_date), do: ""

  defp parse_date(%Date{} = date), do: date

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _error -> nil
    end
  end

  defp parse_date(_value), do: nil

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

  defp plural_suffix(1), do: ""
  defp plural_suffix(_count), do: "s"

  defp performance_chart(rows) do
    monthly_points =
      rows
      |> Enum.sort_by(& &1.week_ending_on, Date)
      |> Enum.group_by(& &1.month)
      |> Enum.map(fn {month, month_rows} ->
        %{
          month: month,
          sort_date: Enum.min_by(month_rows, & &1.week_ending_on).week_ending_on,
          actual: Enum.reduce(month_rows, 0.0, &(&1.actual_yield + &2)),
          expected: Enum.reduce(month_rows, 0.0, &(&1.expected_yield + &2))
        }
      end)
      |> Enum.sort_by(& &1.sort_date, Date)

    %{
      type: "line",
      valueFormat: "quantity",
      data: %{
        labels: Enum.map(monthly_points, & &1.month),
        datasets: [
          %{
            label: "Actual yield",
            data: Enum.map(monthly_points, &Float.round(&1.actual, 1)),
            borderColor: "#5d9138",
            backgroundColor: "rgba(93, 145, 56, 0.12)",
            tension: 0.35,
            fill: true
          },
          %{
            label: "Expected yield",
            data: Enum.map(monthly_points, &Float.round(&1.expected, 1)),
            borderColor: "#f3d74f",
            backgroundColor: "rgba(243, 215, 79, 0.12)",
            tension: 0.35,
            fill: false
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
