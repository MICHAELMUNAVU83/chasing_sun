defmodule ChasingSunWeb.FinanceDashboardLive do
  use ChasingSunWeb, :live_view

  alias ChasingSun.Finance

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(ChasingSun.PubSub, Finance.finance_topic())
    end

    Finance.sync_overdue_invoices!()

    {:ok,
     socket
     |> assign(:page_title, "Finance")
     |> load_totals()}
  end

  @impl true
  def handle_info({:transaction_created, _payload}, socket) do
    {:noreply, load_totals(socket)}
  end

  defp load_totals(socket) do
    assign(socket,
      totals: Finance.dashboard_totals(),
      trend: Finance.trend_last_weeks()
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-8">
      <h1 class="page-title">Finance</h1>
      <.finance_subnav current={:dashboard} />

      <div class="grid gap-6 lg:grid-cols-3">
        <div :for={{period, label} <- period_labels()} class="metric-card">
          <div class="metric-label">{label}</div>
          <div class="mt-3 space-y-2">
            <div class="flex items-baseline justify-between gap-4">
              <span class="text-xs text-zinc-400">Revenue</span>
              <span class="text-lg font-semibold text-zinc-900">
                {format_currency(revenue_total(@totals, period))}
              </span>
            </div>
            <div class="flex items-baseline justify-between gap-4">
              <span class="text-xs text-zinc-400">Expense</span>
              <span class="text-lg font-semibold text-zinc-900">
                {format_currency(expense_total(@totals, period))}
              </span>
            </div>
          </div>
          <div class="mt-3 flex items-center justify-between border-t border-zinc-100 pt-2 text-xs text-zinc-400">
            <span>Net</span>
            <span class={net_class(net_total(@totals, period))}>
              {format_currency(net_total(@totals, period))}
            </span>
          </div>
        </div>
      </div>

      <div class="grid gap-6 xl:grid-cols-[minmax(0,1.55fr)_minmax(320px,0.9fr)]">
        <div class="panel-shell">
          <div class="flex items-center justify-between gap-4">
            <div>
              <p class="eyebrow">Cashflow</p>
              <h2 class="section-heading">Revenue vs expense</h2>
            </div>
            <p class="text-sm text-zinc-400">Last 12 weeks</p>
          </div>
          <div class="chart-frame">
            <canvas
              id="finance-trend-chart"
              phx-hook="ChartRenderer"
              data-chart={Jason.encode!(trend_chart(@trend))}
            />
          </div>
        </div>

        <div class="panel-shell">
          <p class="eyebrow">This month</p>
          <h2 class="section-heading">Business line mix</h2>
          <div class="chart-frame">
            <canvas
              id="finance-business-line-chart"
              phx-hook="ChartRenderer"
              data-chart={Jason.encode!(business_line_chart(@totals))}
            />
          </div>
        </div>
      </div>

      <div class="grid gap-6 w-full">
        <div class="panel-shell">
          <p class="eyebrow">This month</p>
          <h2 class="section-heading">Revenue and expenses</h2>
          <div class="chart-frame">
            <canvas
              id="finance-month-split-chart"
              phx-hook="ChartRenderer"
              data-chart={Jason.encode!(month_split_chart(@totals))}
            />
          </div>
        </div>
      </div>

      <div class="panel-shell">
        <p class="eyebrow">Weekly detail</p>
        <h2 class="section-heading">Last 12 weeks</h2>
        <div class="mt-6 overflow-x-auto">
          <table class="data-table">
            <thead>
              <tr>
                <th>Week starting</th>
                <th>Revenue</th>
                <th>Expense</th>
                <th>Net</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={row <- @trend}>
                <td>{format_date(row.week_start)}</td>
                <td>{format_currency(row.revenue)}</td>
                <td>{format_currency(row.expense)}</td>
                <td class={net_class(Decimal.sub(row.revenue, row.expense))}>
                  {format_currency(Decimal.sub(row.revenue, row.expense))}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
      <div class="panel-shell">
        <p class="eyebrow">Snapshot</p>
        <h2 class="section-heading">Business line totals</h2>
        <div class="mt-6 overflow-x-auto">
          <table class="data-table">
            <thead>
              <tr>
                <th>Period</th>
                <th>Horticulture revenue</th>
                <th>Horticulture expense</th>
                <th>Commodity revenue</th>
                <th>Commodity expense</th>
                <th>Net</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={{period, label} <- period_labels()}>
                <td>{label}</td>
                <td>{format_currency(get_total(@totals, period, :revenue, :horticulture))}</td>
                <td>{format_currency(get_total(@totals, period, :expense, :horticulture))}</td>
                <td>{format_currency(get_total(@totals, period, :revenue, :commodity))}</td>
                <td>{format_currency(get_total(@totals, period, :expense, :commodity))}</td>
                <td class={net_class(net_total(@totals, period))}>
                  {format_currency(net_total(@totals, period))}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>
    """
  end

  defp period_labels, do: [{:today, "Today"}, {:week, "This week"}, {:month, "This month"}]

  defp revenue_total(totals, period), do: totals[period].revenue |> Map.values() |> sum_decimals()
  defp expense_total(totals, period), do: totals[period].expense |> Map.values() |> sum_decimals()

  defp net_total(totals, period),
    do: Decimal.sub(revenue_total(totals, period), expense_total(totals, period))

  defp get_total(totals, period, type, business_line) do
    get_in(totals, [period, type, business_line]) || Decimal.new(0)
  end

  defp trend_chart(trend) do
    labels = Enum.map(trend, &format_date(&1.week_start))

    %{
      type: "line",
      data: %{
        labels: labels,
        datasets: [
          %{
            label: "Revenue",
            data: Enum.map(trend, &decimal_to_float(&1.revenue)),
            borderColor: "#3f722f",
            backgroundColor: "rgba(63, 114, 47, 0.14)",
            tension: 0.35,
            fill: true,
            valueFormat: "kes"
          },
          %{
            label: "Expense",
            data: Enum.map(trend, &decimal_to_float(&1.expense)),
            borderColor: "#dc8a00",
            backgroundColor: "rgba(220, 138, 0, 0.12)",
            tension: 0.35,
            fill: true,
            valueFormat: "kes"
          },
          %{
            label: "Net",
            data: Enum.map(trend, &decimal_to_float(Decimal.sub(&1.revenue, &1.expense))),
            borderColor: "#2563eb",
            backgroundColor: "rgba(37, 99, 235, 0.1)",
            borderDash: [6, 4],
            tension: 0.35,
            valueFormat: "kes"
          }
        ]
      },
      valueFormats: %{y: "kes"},
      options: %{
        interaction: %{mode: "index", intersect: false},
        scales: %{
          x: %{grid: %{display: false}},
          y: %{beginAtZero: true}
        }
      }
    }
  end

  defp business_line_chart(totals) do
    %{
      type: "doughnut",
      data: %{
        labels: ["Horticulture", "Commodity"],
        datasets: [
          %{
            data: [
              decimal_to_float(business_line_activity(totals, :month, :horticulture)),
              decimal_to_float(business_line_activity(totals, :month, :commodity))
            ],
            backgroundColor: ["#3f722f", "#f3d74f"],
            borderColor: "#ffffff",
            borderWidth: 3,
            valueFormat: "kes"
          }
        ]
      },
      options: %{
        cutout: "62%",
        plugins: %{legend: %{position: "bottom"}}
      }
    }
  end

  defp month_split_chart(totals) do
    %{
      type: "bar",
      data: %{
        labels: ["Revenue", "Expense", "Net"],
        datasets: [
          %{
            label: "This month",
            data: [
              decimal_to_float(revenue_total(totals, :month)),
              decimal_to_float(expense_total(totals, :month)),
              decimal_to_float(net_total(totals, :month))
            ],
            backgroundColor: ["#3f722f", "#dc8a00", "#2563eb"],
            borderRadius: 6,
            valueFormat: "kes"
          }
        ]
      },
      valueFormats: %{y: "kes"},
      options: %{
        plugins: %{legend: %{display: false}},
        scales: %{
          x: %{grid: %{display: false}},
          y: %{beginAtZero: true}
        }
      }
    }
  end

  defp business_line_activity(totals, period, business_line) do
    Decimal.add(
      get_total(totals, period, :revenue, business_line),
      get_total(totals, period, :expense, business_line)
    )
  end

  defp sum_decimals(values), do: Enum.reduce(values, Decimal.new(0), &Decimal.add/2)

  defp decimal_to_float(%Decimal{} = value), do: Decimal.to_float(value)
  defp decimal_to_float(nil), do: 0.0
  defp decimal_to_float(value) when is_number(value), do: value / 1

  defp net_class(value) do
    if Decimal.compare(value, 0) == :lt do
      "font-semibold text-rose-700"
    else
      "font-semibold text-emerald-700"
    end
  end

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")
end
