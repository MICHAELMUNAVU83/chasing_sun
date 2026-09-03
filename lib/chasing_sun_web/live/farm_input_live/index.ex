defmodule ChasingSunWeb.FarmInputLive.Index do
  use ChasingSunWeb, :live_view

  alias ChasingSun.FarmInputs

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Farm Inputs")
     |> assign(:input_quantities, %{})
     |> assign(:chosen_farm_input_id, nil)
     |> assign(:active_tab, "base")
     |> assign(:purchase_filters, empty_purchase_filters())
     |> assign(:purchase_filter_form, purchase_filter_form())
     |> assign(:purchase_modal_open, false)
     |> assign(:input_modal_open, false)
     |> assign(:current_input, nil)
     |> assign(:purchase_form, purchase_form())
     |> assign(:input_form, to_form(FarmInputs.change_input(), as: :input))
     |> load_farm_inputs()}
  end

  @impl true
  def handle_event("price_farm_inputs", params, socket) do
    quantities = Map.get(params, "quantities", socket.assigns.input_quantities)

    {:noreply,
     socket
     |> assign(:input_quantities, quantities)
     |> assign(:purchase_form, to_form(Map.get(params, "purchase", %{}), as: :purchase))}
  end

  def handle_event("choose_farm_input", %{"farm_input_id" => id}, socket) do
    {:noreply, assign(socket, :chosen_farm_input_id, parse_optional_int(id))}
  end

  def handle_event("select_tab", %{"tab" => tab}, socket) when tab in ["base", "budgeted"] do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("filter_budgeted_inputs", %{"filters" => filters}, socket) do
    {:noreply,
     socket
     |> assign(:purchase_filters, filters)
     |> assign(:purchase_filter_form, to_form(filters, as: :filters))
     |> load_farm_inputs()}
  end

  def handle_event("clear_budgeted_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:purchase_filters, empty_purchase_filters())
     |> assign(:purchase_filter_form, purchase_filter_form())
     |> load_farm_inputs()}
  end

  def handle_event("delete_budgeted_input", %{"id" => id}, socket) do
    case FarmInputs.delete_purchase_line(id) do
      {:ok, _line} ->
        {:noreply,
         socket
         |> put_flash(:info, "Budgeted input deleted.")
         |> load_farm_inputs()}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "The budgeted input could not be deleted.")}
    end
  end

  def handle_event("open_purchase_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:input_quantities, %{})
     |> assign(:chosen_farm_input_id, nil)
     |> assign(:purchase_form, purchase_form())
     |> assign(:purchase_modal_open, true)}
  end

  def handle_event("close_purchase_modal", _params, socket) do
    {:noreply, assign(socket, :purchase_modal_open, false)}
  end

  def handle_event("open_input_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:current_input, nil)
     |> assign(:input_form, to_form(FarmInputs.change_input(), as: :input))
     |> assign(:input_modal_open, true)}
  end

  def handle_event("edit_input", %{"id" => id}, socket) do
    input = FarmInputs.get_input!(id)

    {:noreply,
     socket
     |> assign(:current_input, input)
     |> assign(:input_form, to_form(FarmInputs.change_input(input), as: :input))
     |> assign(:input_modal_open, true)}
  end

  def handle_event("close_input_modal", _params, socket) do
    {:noreply, assign(socket, :input_modal_open, false)}
  end

  def handle_event("save_farm_input_purchase", params, socket) do
    quantities = Map.get(params, "quantities", socket.assigns.input_quantities)

    lines =
      Enum.map(socket.assigns.farm_inputs, fn input ->
        %{
          farm_input_id: input.id,
          quantity: Map.get(quantities, to_string(input.id), "0"),
          unit_price: input.unit_price
        }
      end)

    case FarmInputs.create_purchase(
           Map.get(params, "purchase", %{}),
           lines,
           socket.assigns.current_user
         ) do
      {:ok, _purchase} ->
        {:noreply,
         socket
         |> put_flash(:info, "Farm input purchase recorded.")
         |> assign(:input_quantities, %{})
         |> assign(:chosen_farm_input_id, nil)
         |> assign(:purchase_form, purchase_form())
         |> assign(:purchase_modal_open, false)
         |> assign(:active_tab, "budgeted")
         |> load_farm_inputs()}

      {:error, :no_items} ->
        {:noreply, put_flash(socket, :error, "Enter a quantity for at least one input.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :purchase_form, to_form(changeset, as: :purchase))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "The purchase could not be recorded.")}
    end
  end

  def handle_event("save_farm_input", %{"input" => attrs}, socket) do
    result =
      case socket.assigns.current_input do
        nil -> FarmInputs.create_input(attrs)
        input -> FarmInputs.update_input(input, attrs)
      end

    case result do
      {:ok, _input} ->
        {:noreply,
         socket
         |> put_flash(:info, input_saved_message(socket.assigns.current_input))
         |> assign(:input_modal_open, false)
         |> assign(:current_input, nil)
         |> assign(:input_form, to_form(FarmInputs.change_input(), as: :input))
         |> load_farm_inputs()}

      {:error, changeset} ->
        {:noreply, assign(socket, :input_form, to_form(changeset, as: :input))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-8">
      <div class="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p class="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--brand-green-deep)]">
            Purchasing
          </p>
          <h1 class="page-title mt-2">Farm inputs</h1>
          <p class="mt-2 text-sm text-[var(--muted)]">
            Build a purchase from the input database and track monthly consumption and cost.
          </p>
        </div>
        <div class="flex flex-wrap items-center gap-3">
          <button type="button" phx-click="open_input_modal" class="nav-chip">Add input</button>
          <.button type="button" phx-click="open_purchase_modal">Record purchase</.button>
        </div>
      </div>

      <div class="grid gap-4 sm:grid-cols-3">
        <.input_metric
          label="Average monthly packs"
          value={format_decimal(@analytics.average_quantity)}
        />
        <.input_metric label="Average monthly cost" value={format_money(@analytics.average_cost)} />
        <.input_metric label="Expected next-month cost" value={forecast_label(@analytics)} />
      </div>
      <p :if={is_nil(@analytics.forecast_cost)} class="text-xs text-[var(--muted)]">
        A prediction will appear after purchases have been recorded in three different months ({@analytics.month_count}/3 so far).
      </p>

      <div class="panel-shell">
        <div
          class="mb-6 flex gap-2 border-b border-[var(--line)]"
          role="tablist"
          aria-label="Farm inputs"
        >
          <button
            type="button"
            role="tab"
            aria-selected={@active_tab == "base"}
            phx-click="select_tab"
            phx-value-tab="base"
            class={tab_class(@active_tab, "base")}
          >
            Base inputs
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={@active_tab == "budgeted"}
            phx-click="select_tab"
            phx-value-tab="budgeted"
            class={tab_class(@active_tab, "budgeted")}
          >
            Budgeted inputs
          </button>
        </div>
        <div :if={@active_tab == "base"}>
          <div class="flex items-center justify-between gap-4">
            <div>
              <h2 class="section-heading">Base inputs</h2>
              <p class="mt-2 text-sm text-[var(--muted)]">
                Update input names, pack sizes, and current prices used for new purchases.
              </p>
            </div>
            <button type="button" phx-click="open_input_modal" class="nav-chip">Add input</button>
          </div>
          <div class="mt-5 overflow-x-auto">
            <table class="data-table">
              <thead>
                <tr>
                  <th>Input</th>
                  <th>Pack size</th>
                  <th class="text-right">Current price</th>
                  <th class="w-24"></th>
                </tr>
              </thead>
              <tbody>
                <tr :for={input <- @farm_inputs}>
                  <td class="font-semibold text-[var(--ink)]">{input.name}</td>
                  <td>{input.pack_size}</td>
                  <td class="text-right">{format_money(input.unit_price)}</td>
                  <td class="text-right">
                    <button
                      type="button"
                      phx-click="edit_input"
                      phx-value-id={input.id}
                      class="action-link"
                    >
                      Edit
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
        <div :if={@active_tab == "budgeted"}>
          <div class="flex items-center justify-between gap-4">
            <div>
              <h2 class="section-heading">Budgeted inputs</h2>
              <p class="mt-2 text-sm text-[var(--muted)]">
                A history of recorded input purchases and their purchase prices.
              </p>
            </div>
            <.button type="button" phx-click="open_purchase_modal">Record purchase</.button>
          </div>
          <.form
            for={@purchase_filter_form}
            phx-change="filter_budgeted_inputs"
            class="mt-5 grid gap-3 rounded-2xl bg-[var(--surface-soft)] p-4 sm:grid-cols-2 lg:grid-cols-5"
          >
            <.input field={@purchase_filter_form[:from]} type="date" label="From date" />
            <.input field={@purchase_filter_form[:to]} type="date" label="To date" />
            <.input
              field={@purchase_filter_form[:input_id]}
              type="select"
              label="Input"
              prompt="All inputs"
              options={Enum.map(@farm_inputs, &{&1.name, &1.id})}
            />
            <.input
              field={@purchase_filter_form[:farm]}
              label="Farm / location"
              placeholder="All locations"
              phx-debounce="300"
            />
            <div class="flex items-end">
              <button type="button" phx-click="clear_budgeted_filters" class="nav-chip w-full">
                Clear filters
              </button>
            </div>
          </.form>
          <div class="mt-5 overflow-x-auto">
            <table class="data-table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Input</th>
                  <th>Farm / location</th>
                  <th class="text-right">Quantity</th>
                  <th class="text-right">Unit price</th>
                  <th class="text-right">Total</th>
                  <th class="w-20"></th>
                </tr>
              </thead>
              <tbody>
                <tr :for={line <- @purchase_lines}>
                  <td>{format_date(line.purchase.purchased_on)}</td>
                  <td>
                    <span class="font-semibold text-[var(--ink)]">{line.farm_input.name}</span><span class="block text-xs text-[var(--muted)]">{line.farm_input.pack_size}</span>
                  </td>
                  <td>{line.purchase.farm || "—"}</td>
                  <td class="text-right">{format_decimal(line.quantity)}</td>
                  <td class="text-right">{format_money(line.unit_price)}</td>
                  <td class="text-right font-semibold">
                    {format_money(Decimal.mult(line.quantity, line.unit_price))}
                  </td>
                  <td class="text-right">
                    <button
                      type="button"
                      phx-click="delete_budgeted_input"
                      phx-value-id={line.id}
                      data-confirm="Delete this budgeted input? This cannot be undone."
                      class="action-link text-red-700"
                    >
                      Delete
                    </button>
                  </td>
                </tr>
                <tr :if={Enum.empty?(@purchase_lines)}>
                  <td colspan="7" class="text-center text-[var(--muted)]">
                    No budgeted inputs match these filters.
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <.modal
        :if={@purchase_modal_open}
        id="farm-input-purchase-modal"
        show
        on_cancel={JS.push("close_purchase_modal")}
      >
        <div class="p-1">
          <p class="eyebrow">Purchasing</p>
          <div class="flex items-end justify-between gap-4">
            <h2 class="section-heading mt-2">Record purchase</h2>
            <p class="text-lg font-semibold text-[var(--ink)]">
              {format_money(input_purchase_total(@farm_inputs, @input_quantities))}
            </p>
          </div>
          <form
            phx-change="price_farm_inputs"
            phx-submit="save_farm_input_purchase"
            class="mt-6 space-y-5"
          >
            <div class="grid gap-4 sm:grid-cols-2">
              <.input
                field={@purchase_form[:purchased_on]}
                type="date"
                label="Purchase date"
                required
              /><.input
                field={@purchase_form[:farm]}
                label="Farm / location"
                placeholder="e.g. Kisii"
              />
            </div>
            <.input field={@purchase_form[:notes]} label="Notes" placeholder="Optional" />
            <div>
              <label
                for="farm-input-picker"
                class="text-[11px] font-semibold uppercase tracking-[0.18em] text-[var(--muted)]"
              >
                Choose an input
              </label>
              <select
                id="farm-input-picker"
                name="farm_input_id"
                phx-change="choose_farm_input"
                class="mt-2 w-full rounded-2xl border border-[var(--line)] bg-white px-4 py-3 text-sm font-semibold text-[var(--ink)]"
              >
                <option value="">Select from the database…</option>
                <option
                  :for={input <- @farm_inputs}
                  value={input.id}
                  selected={@chosen_farm_input_id == input.id}
                >
                  {input.name} · {input.pack_size} · {format_money(input.unit_price)}
                </option>
              </select>
            </div>
            <div class="max-h-72 overflow-auto">
              <table class="data-table">
                <thead>
                  <tr>
                    <th>Input</th>
                    <th class="text-right">Price</th>
                    <th>Quantity</th>
                    <th class="text-right">Cost</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={
                    input <- purchase_inputs(@farm_inputs, @chosen_farm_input_id, @input_quantities)
                  }>
                    <td class="font-semibold text-[var(--ink)]">
                      {input.name}<span class="block text-xs font-normal text-[var(--muted)]">{input.pack_size}</span>
                    </td>
                    <td class="text-right">{format_money(input.unit_price)}</td>
                    <td>
                      <input
                        type="number"
                        name={"quantities[#{input.id}]"}
                        value={Map.get(@input_quantities, to_string(input.id), "")}
                        min="0"
                        step="0.01"
                        placeholder="0"
                        class="w-24 rounded-xl border border-[var(--line)] bg-white px-3 py-2 text-right"
                      />
                    </td>
                    <td class="text-right font-semibold">
                      {format_money(input_line_total(input, @input_quantities))}
                    </td>
                  </tr>
                  <tr :if={
                    Enum.empty?(
                      purchase_inputs(@farm_inputs, @chosen_farm_input_id, @input_quantities)
                    )
                  }>
                    <td colspan="4" class="text-center text-[var(--muted)]">
                      Choose an input above.
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div class="flex justify-end gap-3">
              <button type="button" phx-click="close_purchase_modal" class="nav-chip">Cancel</button>
              <.button type="submit">Record purchase</.button>
            </div>
          </form>
        </div>
      </.modal>

      <.modal
        :if={@input_modal_open}
        id="farm-input-modal"
        show
        on_cancel={JS.push("close_input_modal")}
      >
        <div class="p-1">
          <p class="eyebrow">Input database</p>
          <h2 class="section-heading mt-2">{input_modal_title(@current_input)}</h2>
          <p class="mt-2 text-sm text-[var(--muted)]">
            Price changes apply to future purchases; existing purchase history keeps its original price.
          </p>
          <.form for={@input_form} phx-submit="save_farm_input" class="mt-6 space-y-4">
            <.input field={@input_form[:name]} label="Input name" required />
            <.input
              field={@input_form[:pack_size]}
              label="Pack size"
              placeholder="e.g. 1 litre"
              required
            />
            <.input
              field={@input_form[:unit_price]}
              type="number"
              min="0"
              step="0.01"
              label="Unit price (KES)"
              required
            />
            <div class="flex justify-end gap-3 pt-2">
              <button type="button" phx-click="close_input_modal" class="nav-chip">Cancel</button>
              <.button type="submit">{input_submit_label(@current_input)}</.button>
            </div>
          </.form>
        </div>
      </.modal>
    </section>
    """
  end

  defp purchase_form do
    to_form(%{"purchased_on" => Date.to_iso8601(Date.utc_today()), "farm" => ""}, as: :purchase)
  end

  defp empty_purchase_filters,
    do: %{"from" => "", "to" => "", "input_id" => "", "farm" => ""}

  defp purchase_filter_form, do: to_form(empty_purchase_filters(), as: :filters)

  defp load_farm_inputs(socket) do
    assign(socket,
      farm_inputs: FarmInputs.list_inputs(),
      purchase_lines: FarmInputs.list_purchase_lines(socket.assigns.purchase_filters),
      analytics: FarmInputs.analytics()
    )
  end

  defp purchase_inputs(inputs, chosen_id, quantities) do
    Enum.filter(inputs, fn input ->
      input.id == chosen_id or
        Decimal.compare(parse_decimal(Map.get(quantities, to_string(input.id), "0")), 0) == :gt
    end)
  end

  defp input_purchase_total(inputs, quantities),
    do: Enum.reduce(inputs, Decimal.new(0), &Decimal.add(&2, input_line_total(&1, quantities)))

  defp input_line_total(input, quantities),
    do:
      Decimal.mult(input.unit_price, parse_decimal(Map.get(quantities, to_string(input.id), "0")))

  defp parse_decimal(value) do
    case Decimal.parse(to_string(value || "0")) do
      {decimal, ""} -> decimal
      _ -> Decimal.new(0)
    end
  end

  defp format_money(value),
    do: "KES " <> (value |> Decimal.round(2) |> Decimal.to_string(:normal))

  defp format_decimal(value), do: value |> Decimal.round(1) |> Decimal.to_string(:normal)
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")

  defp tab_class(active, tab) do
    base = "border-b-2 px-4 py-3 text-sm font-semibold transition"

    if active == tab,
      do: base <> " border-[var(--brand-green-deep)] text-[var(--brand-green-deep)]",
      else: base <> " border-transparent text-[var(--muted)] hover:text-[var(--ink)]"
  end

  defp forecast_label(%{forecast_cost: nil}), do: "Pending history"
  defp forecast_label(%{forecast_cost: cost}), do: format_money(cost)
  defp input_modal_title(nil), do: "Add farm input"
  defp input_modal_title(input), do: "Edit #{input.name}"
  defp input_submit_label(nil), do: "Add input"
  defp input_submit_label(_input), do: "Save changes"
  defp input_saved_message(nil), do: "Farm input added to the database."
  defp input_saved_message(_input), do: "Farm input updated."
  defp parse_optional_int(nil), do: nil
  defp parse_optional_int(""), do: nil

  defp parse_optional_int(value) do
    case Integer.parse(to_string(value)) do
      {number, ""} -> number
      _ -> nil
    end
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp input_metric(assigns) do
    ~H"""
    <div class="rounded-[1.5rem] border border-[var(--line)] bg-[var(--surface-soft)] p-4">
      <p class="text-xs uppercase tracking-[0.16em] text-[var(--muted)]">{@label}</p>
      <p class="mt-2 text-xl font-semibold text-[var(--ink)]">{@value}</p>
    </div>
    """
  end
end
