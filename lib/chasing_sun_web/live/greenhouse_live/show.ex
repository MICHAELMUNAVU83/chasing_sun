defmodule ChasingSunWeb.GreenhouseLive.Show do
  use ChasingSunWeb, :live_view

  alias ChasingSun.Operations
  alias ChasingSun.Operations.CropPlanner

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(ChasingSun.PubSub, Operations.operations_topic())
    end

    {:ok, assign(socket, :crop_rules, Operations.list_crop_rules())}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    {:noreply, socket |> assign(:greenhouse_id, id) |> load_greenhouse()}
  end

  @impl true
  def handle_info({:operations_refreshed, _today}, socket) do
    {:noreply, load_greenhouse(socket)}
  end

  def handle_info({:operation_notification, _notification}, socket) do
    {:noreply, load_greenhouse(socket)}
  end

  @impl true
  def handle_event("terminate_production", _params, socket) do
    if ChasingSunWeb.UserAuth.can?(socket.assigns.current_user, :manage_greenhouses) do
      greenhouse = Operations.get_greenhouse!(socket.assigns.greenhouse_id)

      case Operations.terminate_production(greenhouse, socket.assigns.current_user) do
        {:ok, _cycle} ->
          {:noreply,
           socket
           |> put_flash(
             :info,
             "Production terminated. Soil recovery has started for this greenhouse."
           )
           |> load_greenhouse()}

        {:error, :no_active_cycle} ->
          {:noreply, put_flash(socket, :error, "No active crop cycle is available to stop.")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, put_flash(socket, :error, changeset_error_summary(changeset))}
      end
    else
      {:noreply, put_flash(socket, :error, "You do not have permission to manage greenhouses.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-6">
      <div class="panel-shell">
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p class="eyebrow">Estate Registry</p>
            <h1 class="page-title">{@greenhouse.name}</h1>
            <p class="mt-2 text-sm uppercase tracking-[0.18em] text-[var(--muted)]">
              Unit {@greenhouse.sequence_no} · {format_size(@greenhouse.size)} · Tank {@greenhouse.tank ||
                "-"}
            </p>
            <p class="mt-3 text-sm text-[var(--muted)]">
              {@greenhouse.venture.name} · {String.upcase(@greenhouse.venture.code)} ·
              <span class={if(@greenhouse.active, do: "text-[var(--brand-green-deep)]", else: "")}>
                {if @greenhouse.active, do: "Active unit", else: "Inactive"}
              </span>
            </p>
          </div>
          <div class="flex items-center gap-3">
            <.status_badge status={@cycle && @cycle.status_cache} />
            <.link navigate={~p"/greenhouses"} class="nav-chip">Back to registry</.link>
          </div>
        </div>

        <div class="mt-8 grid gap-4 md:grid-cols-3">
          <.summary_card
            title="Latest harvest"
            value={latest_yield_label(@latest_harvest)}
            hint={latest_harvest_hint(@latest_harvest)}
          />
          <.summary_card
            title="Total harvested"
            value={format_number(@total_yield, decimals: 1)}
            hint={"Across #{length(@greenhouse.harvest_records)} record(s)"}
            accent="yellow"
          />
          <.summary_card
            title="Expected weekly yield"
            value={format_number(@expected_output, decimals: 1)}
            hint="Based on the active crop cycle"
            accent="ink"
          />
        </div>
      </div>

      <div class="grid gap-6 lg:grid-cols-2">
        <div class="panel-shell">
          <p class="eyebrow">Crop Cycle</p>
          <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
            Active cycle
          </h2>

          <%= case @cycle do %>
            <% nil -> %>
              <p class="mt-4 rounded-[1.5rem] border border-dashed border-[var(--line)] p-5 text-sm text-[var(--muted)]">
                No active crop cycle registered for this greenhouse.
              </p>
            <% cycle -> %>
              <div class="mt-4 space-y-1">
                <p class="text-lg font-semibold text-[var(--ink)]">{cycle.crop_type}</p>
                <p class="text-sm text-[var(--muted)]">
                  {cycle.variety || "Variety pending"} · {format_count(cycle.plant_count)} plants
                </p>
              </div>

              <button
                :if={@cycle && @cycle.status_cache == :harvesting}
                type="button"
                phx-click="terminate_production"
                data-confirm="Stop production now and start soil recovery for this greenhouse?"
                class="mt-5 inline-flex items-center rounded-[1.25rem] bg-rose-600 px-4 py-3 text-sm font-semibold text-white transition hover:bg-rose-700"
              >
                Terminate production
              </button>

              <dl class="mt-6 grid gap-3 sm:grid-cols-2">
                <.detail label="Nursery date" value={format_date(cycle.nursery_date)} />
                <.detail label="Transplant date" value={format_date(cycle.transplant_date)} />
                <.detail label="Harvest start" value={format_date(cycle.harvest_start_date)} />
                <.detail label="Harvest end" value={format_date(cycle.harvest_end_date)} />
                <.detail label="Soil recovery end" value={format_date(cycle.soil_recovery_end_date)} />
              </dl>
          <% end %>
        </div>

        <div class="panel-shell">
          <p class="eyebrow">Operations Recommendation</p>
          <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
            Next move
          </h2>

          <%= case @greenhouse.operation_recommendation do %>
            <% nil -> %>
              <p class="mt-4 rounded-[1.5rem] border border-dashed border-[var(--line)] p-5 text-sm text-[var(--muted)]">
                No recommendation yet. Add an active crop cycle to plan the next move.
              </p>
            <% recommendation -> %>
              <p class="mt-4 text-sm text-[var(--muted)]">
                Current crop: {recommendation.current_crop}
              </p>
              <p class="mt-3 text-sm font-semibold text-[var(--brand-green-deep)]">
                Next crop: {recommendation.next_crop}
              </p>
              <p class="mt-2 text-sm text-[var(--muted)]">{recommendation.note}</p>
              <div class="mt-4 flex flex-wrap gap-2 text-xs text-[var(--muted)]">
                <span :if={recommendation.nursery_date} class="rounded-full bg-white px-3 py-1">
                  Nursery {format_date(recommendation.nursery_date)}
                </span>
                <span :if={recommendation.transplant_date} class="rounded-full bg-white px-3 py-1">
                  Transplant {format_date(recommendation.transplant_date)}
                </span>
                <span :if={recommendation.harvest_start_date} class="rounded-full bg-white px-3 py-1">
                  Harvest starts {format_date(recommendation.harvest_start_date)}
                </span>
              </div>
          <% end %>
        </div>
      </div>

      <div class="panel-shell">
        <p class="eyebrow">History</p>
        <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
          Harvest history
        </h2>

        <div class="mt-6 overflow-x-auto">
          <table class="data-table">
            <thead>
              <tr>
                <th>Week ending</th>
                <th>Actual yield</th>
                <th>Notes</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={record <- @greenhouse.harvest_records}>
                <td class="font-semibold text-[var(--ink)]">{format_date(record.week_ending_on)}</td>
                <td>{format_number(record.actual_yield, decimals: 1)}</td>
                <td class="text-[var(--muted)]">{record.notes || "-"}</td>
              </tr>
              <tr :if={Enum.empty?(@greenhouse.harvest_records)}>
                <td colspan="3" class="text-center text-sm text-[var(--muted)]">
                  No harvest records yet for this greenhouse.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>
    """
  end

  defp detail(assigns) do
    ~H"""
    <div class="rounded-2xl border border-[var(--line)] bg-white/70 px-3 py-2">
      <p class="text-[11px] font-semibold uppercase tracking-[0.18em] text-[var(--muted)]">
        {@label}
      </p>
      <p class="mt-1 text-sm font-semibold text-[var(--ink)]">{@value}</p>
    </div>
    """
  end

  defp load_greenhouse(socket) do
    greenhouse = Operations.get_greenhouse!(socket.assigns.greenhouse_id)
    cycle = Operations.current_cycle(greenhouse)

    expected_output =
      if cycle, do: CropPlanner.expected_yield(cycle, socket.assigns.crop_rules), else: 0.0

    total_yield =
      Enum.reduce(greenhouse.harvest_records, 0.0, &(&1.actual_yield + &2))

    socket
    |> assign(:page_title, "Greenhouses")
    |> assign(:greenhouse, greenhouse)
    |> assign(:cycle, cycle)
    |> assign(:latest_harvest, List.first(greenhouse.harvest_records))
    |> assign(:expected_output, expected_output)
    |> assign(:total_yield, total_yield)
  end

  defp latest_yield_label(nil), do: "No data"
  defp latest_yield_label(record), do: format_number(record.actual_yield, decimals: 1)

  defp latest_harvest_hint(nil), do: "No harvest recorded yet"
  defp latest_harvest_hint(record), do: "Week ending #{format_date(record.week_ending_on)}"

  defp format_count(nil), do: "0"
  defp format_count(value), do: format_number(value, decimals: 0)

  defp format_size(nil), do: "size unset"
  defp format_size("8x40"), do: "8 x 40"
  defp format_size("16x40"), do: "16 x 40"
  defp format_size(size), do: size

  defp format_date(nil), do: "-"
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")

  defp changeset_error_summary(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, _opts} -> message end)
    |> Enum.flat_map(fn {field, messages} ->
      Enum.map(messages, &"#{Phoenix.Naming.humanize(field)} #{&1}")
    end)
    |> Enum.join(", ")
  end
end
