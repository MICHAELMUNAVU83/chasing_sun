defmodule ChasingSunWeb.ForecastLive.Index do
  use ChasingSunWeb, :live_view

  alias ChasingSun.Analytics
  alias ChasingSun.Operations

  @impl true
  def mount(params, _session, socket) do
    venture_code = params["venture_code"] || "all"

    {:ok,
     socket
     |> assign(:page_title, "Forecast")
     |> load_forecast(venture_code)}
  end

  @impl true
  def handle_event("filter", %{"venture_code" => venture_code}, socket) do
    {:noreply, load_forecast(socket, venture_code)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-6">
      <div class="panel-shell">
        <p class="eyebrow">Forward View</p>
        <h1 class="page-title">Eight-week production forecast</h1>
        <p class="page-copy">
          Use active crop cycles and crop rules to see weekly expected output, projected near-term performance, and upcoming crop-change decisions.
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
            title="8-week expected"
            value={format_quantity(total_expected(@forecast.weeks))}
            hint="Summed across all forecast weeks"
          />
          <.summary_card
            title="Peak week"
            value={peak_week_label(@forecast.weeks)}
            hint="Highest expected weekly output"
            accent="yellow"
          />
          <.summary_card
            title="Next week active units"
            value={next_week_units(@forecast.weeks)}
            hint="Greenhouses projected to harvest next Saturday"
            accent="ink"
          />
        </div>
      </div>

      <div class="grid gap-6 xl:grid-cols-[minmax(0,1.6fr)_minmax(340px,1fr)]">
        <div class="panel-shell">
          <p class="eyebrow">Weekly Forecast</p>
          <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
            Forecasted output by week
          </h2>

          <div class="mt-6 overflow-x-auto">
            <table class="data-table">
              <thead>
                <tr>
                  <th>Week ending</th>
                  <th>Active units</th>
                  <th>Expected output</th>
                  <th>Harvesting units</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={week <- @forecast.weeks}>
                  <td>{format_date(week.week_ending_on)}</td>
                  <td>{week.active_units}</td>
                  <td class="font-semibold text-[var(--ink)]">
                    {format_quantity(week.expected_output)}
                  </td>
                  <td>
                    <div class="flex flex-wrap gap-2">
                      <span
                        :for={greenhouse <- Enum.take(week.greenhouses, 3)}
                        class="rounded-full bg-[var(--surface-soft)] px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em] text-[var(--muted)]"
                      >
                        {greenhouse.name}
                      </span>
                      <span
                        :if={length(week.greenhouses) > 3}
                        class="rounded-full bg-zinc-100 px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em] text-[var(--muted)]"
                      >
                        +{length(week.greenhouses) - 3} more
                      </span>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="space-y-6">
          <div class="panel-shell">
            <p class="eyebrow">Next Saturday</p>
            <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
              Weighted projection
            </h2>

            <div class="mt-6 space-y-4">
              <div
                :for={projection <- @forecast.projection}
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
                  Baseline {format_quantity(projection.expected)} for {format_date(
                    projection.week_ending_on
                  )}
                </p>
              </div>

              <div
                :if={Enum.empty?(@forecast.projection)}
                class="rounded-[1.5rem] border border-dashed border-[var(--line)] p-5 text-sm text-[var(--muted)]"
              >
                No projection available yet. Seed harvest records to activate projections.
              </div>
            </div>
          </div>

          <div class="panel-shell">
            <p class="eyebrow">Upcoming Rotation</p>
            <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
              Recommended next crops
            </h2>

            <div class="mt-6 space-y-4">
              <div
                :for={recommendation <- @forecast.recommendations}
                class="rounded-[1.5rem] border border-[var(--line)] bg-[var(--surface-soft)] p-4"
              >
                <p class="font-semibold text-[var(--ink)]">{recommendation.greenhouse_name}</p>
                <p class="mt-1 text-sm text-[var(--muted)]">
                  Current crop: {recommendation.current_crop}
                </p>
                <p class="mt-3 text-sm font-semibold text-[var(--brand-green-deep)]">
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
                Add crop cycles to generate next-crop suggestions.
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp load_forecast(socket, venture_code) do
    assign(socket,
      selected_venture: venture_code,
      ventures: Operations.list_ventures(),
      forecast: Analytics.forecast(filters_for(venture_code))
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

  defp total_expected(weeks), do: Enum.reduce(weeks, 0.0, &(&1.expected_output + &2))

  defp peak_week_label([]), do: "No data"

  defp peak_week_label(weeks) do
    peak = Enum.max_by(weeks, & &1.expected_output, fn -> nil end)

    if peak do
      "#{format_date(peak.week_ending_on)} · #{format_quantity(peak.expected_output)}"
    else
      "No data"
    end
  end

  defp next_week_units([week | _]), do: week.active_units
  defp next_week_units(_weeks), do: 0

  defp format_quantity(value), do: format_number(value, decimals: 1)

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")
  defp format_date(_date), do: "-"
end
