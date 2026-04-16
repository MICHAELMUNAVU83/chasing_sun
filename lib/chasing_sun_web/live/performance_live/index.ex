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
     |> load_report(venture_code)}
  end

  @impl true
  def handle_event("filter", %{"venture_code" => venture_code}, socket) do
    {:noreply, load_report(socket, venture_code)}
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

  defp load_report(socket, venture_code) do
    assign(socket,
      selected_venture: venture_code,
      ventures: Operations.list_ventures(),
      report: Analytics.performance_report(filters_for(venture_code))
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
