defmodule ChasingSunWeb.RecommendationLive.Index do
  use ChasingSunWeb, :live_view

  alias ChasingSun.Operations

  @impl true
  def mount(params, _session, socket) do
    venture_code = params["venture_code"] || "all"

    if connected?(socket) do
      Phoenix.PubSub.subscribe(ChasingSun.PubSub, Operations.operations_topic())
    end

    {:ok,
     socket
     |> assign(:page_title, "Recommendations")
     |> load_recommendations(venture_code)}
  end

  @impl true
  def handle_event("filter", %{"venture_code" => venture_code}, socket) do
    {:noreply, load_recommendations(socket, venture_code)}
  end

  @impl true
  def handle_info({:operations_refreshed, _today}, socket) do
    {:noreply, load_recommendations(socket, socket.assigns.selected_venture)}
  end

  def handle_info({:operation_notification, _notification}, socket) do
    {:noreply, load_recommendations(socket, socket.assigns.selected_venture)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-10">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <h1 class="page-title">Crop recommendations</h1>

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

      <div class="grid gap-4 md:grid-cols-3">
        <.summary_card title="Active recommendations" value={length(@recommendations)} />
        <.summary_card
          title="Nursery next 7 days"
          value={due_soon_count(@recommendations, :nursery_date)}
        />
        <.summary_card
          title="Transplants next 7 days"
          value={due_soon_count(@recommendations, :transplant_date)}
        />
      </div>

      <div class="grid gap-8 xl:grid-cols-[minmax(0,1.6fr)_minmax(340px,1fr)]">
        <div class="panel-shell">
          <div class="flex items-center justify-between gap-4">
            <h2 class="section-heading">Next crop</h2>
            <p :if={latest_generated_on(@recommendations)} class="text-xs text-zinc-400">
              Updated {format_date(latest_generated_on(@recommendations))}
            </p>
          </div>

          <div class="mt-6 space-y-4">
            <div
              :for={recommendation <- @recommendations}
              class="rounded-xl border border-zinc-200 p-5"
            >
              <div class="flex items-start justify-between gap-4">
                <div>
                  <p class="text-base font-semibold text-[var(--ink)]">
                    {recommendation.greenhouse.name}
                  </p>
                  <p class="mt-1 text-sm text-[var(--muted)]">
                    {recommendation.greenhouse.venture.name} · {String.upcase(
                      recommendation.greenhouse.venture.code
                    )}
                  </p>
                </div>
                <span class="inline-flex items-center rounded-full border border-zinc-200 bg-zinc-50 px-2 py-0.5 text-xs font-medium text-zinc-600">
                  {humanize_kind(recommendation.recommendation_kind)}
                </span>
              </div>

              <div class="mt-4 flex items-center gap-4">
                <div class="flex-1">
                  <p class="text-xs uppercase tracking-wide text-zinc-400">Current crop</p>
                  <p class="mt-1 text-sm font-medium text-[var(--ink)]">
                    {recommendation.current_crop}
                  </p>
                </div>
                <span class="text-zinc-300">→</span>
                <div class="flex-1">
                  <p class="text-xs uppercase tracking-wide text-zinc-400">Recommended next</p>
                  <p class="mt-1 text-sm font-medium text-[var(--brand-green-deep)]">
                    {recommendation_label(recommendation)}
                  </p>
                </div>
              </div>

              <p class="mt-4 text-sm text-[var(--muted)]">
                {recommendation.note}
              </p>

              <div class="mt-4 flex flex-wrap gap-2 text-xs text-[var(--muted)]">
                <span
                  :if={recommendation.soil_recovery_end_date}
                  class="rounded-full border border-zinc-200 bg-zinc-50 px-3 py-1"
                >
                  Soil ready {format_date(recommendation.soil_recovery_end_date)}
                </span>
                <span
                  :if={recommendation.nursery_date}
                  class="rounded-full border border-zinc-200 bg-zinc-50 px-3 py-1"
                >
                  Nursery {format_date(recommendation.nursery_date)}
                </span>
                <span
                  :if={recommendation.transplant_date}
                  class="rounded-full border border-zinc-200 bg-zinc-50 px-3 py-1"
                >
                  Transplant {format_date(recommendation.transplant_date)}
                </span>
                <span
                  :if={recommendation.harvest_start_date}
                  class="rounded-full border border-zinc-200 bg-zinc-50 px-3 py-1"
                >
                  Harvest starts {format_date(recommendation.harvest_start_date)}
                </span>
                <span
                  :if={recommendation.harvest_end_date}
                  class="rounded-full border border-zinc-200 bg-zinc-50 px-3 py-1"
                >
                  Harvest ends {format_date(recommendation.harvest_end_date)}
                </span>
              </div>
            </div>

            <div
              :if={Enum.empty?(@recommendations)}
              class="rounded-[1.5rem] border border-dashed border-[var(--line)] p-5 text-sm text-[var(--muted)]"
            >
              No immediate crop recommendations are available yet. Seed crop cycles and refresh operations to generate rotation guidance.
            </div>
          </div>
        </div>

        <div class="space-y-8">
          <div class="panel-shell">
            <h2 class="section-heading">Alerts</h2>

            <div class="mt-6 space-y-3">
              <div
                :for={notification <- @notifications}
                class="rounded-xl border border-zinc-200 p-4"
              >
                <p class="font-semibold text-[var(--ink)]">{notification.greenhouse.name}</p>
                <p class="mt-1 text-sm text-[var(--muted)]">{notification.message}</p>
                <p class="mt-3 text-xs uppercase tracking-[0.18em] text-[var(--muted)]">
                  {format_date(notification.notify_on)}
                </p>
              </div>

              <div
                :if={Enum.empty?(@notifications)}
                class="rounded-[1.5rem] border border-dashed border-[var(--line)] p-5 text-sm text-[var(--muted)]"
              >
                Notifications appear here when planning checks detect a nursery or rotation action.
              </div>
            </div>
          </div>

          <div class="panel-shell">
            <h2 class="section-heading">Forecast</h2>
            <p class="mt-2 text-sm text-[var(--muted)]">
              The eight-week output view sits alongside these rotation decisions.
            </p>
            <.link navigate={~p"/forecast"} class="action-link mt-4 inline-flex">
              Open forecast
            </.link>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp load_recommendations(socket, venture_code) do
    filters = filters_for(venture_code)

    assign(socket,
      selected_venture: venture_code,
      ventures: Operations.list_ventures(),
      recommendations: Operations.list_operation_recommendations(filters),
      notifications: Operations.recent_operation_notifications(8, filters)
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

  defp humanize_kind(nil), do: "-"
  defp humanize_kind(""), do: "-"

  defp humanize_kind(kind) do
    kind
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp recommendation_label(recommendation) do
    [recommendation.next_crop, recommendation.next_variety]
    |> Enum.reject(&is_nil_or_blank/1)
    |> Enum.join(" · ")
  end

  defp is_nil_or_blank(nil), do: true
  defp is_nil_or_blank(""), do: true
  defp is_nil_or_blank(_value), do: false

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")
  defp format_date(_date), do: "TBD"
end
