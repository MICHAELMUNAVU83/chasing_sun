defmodule ChasingSunWeb.DeliveryNotesLive.Index do
  use ChasingSunWeb, :live_view

  alias ChasingSun.Finance
  alias ChasingSun.Finance.DeliveryNote

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Delivery notes")
     |> assign(:status_filter, "")
     |> assign(:form_modal_open, false)
     |> assign(:current_note, nil)
     |> assign(:clients, Finance.client_options())
     |> load_notes()
     |> reset_form()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :form_modal_open, socket.assigns.live_action == :new)}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply, socket |> assign(:status_filter, status) |> load_notes()}
  end

  def handle_event("open_form_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:current_note, nil)
     |> reset_form()
     |> assign(:form_modal_open, true)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    note = Finance.get_delivery_note!(id)

    {:noreply,
     socket
     |> assign(:current_note, note)
     |> assign(:form, to_form(Finance.change_delivery_note(note)))
     |> assign(:form_modal_open, true)}
  end

  def handle_event("close_form_modal", _params, socket) do
    {:noreply, socket |> assign(:form_modal_open, false) |> reset_form()}
  end

  def handle_event("validate", %{"delivery_note" => params}, socket) do
    changeset =
      Finance.change_delivery_note(socket.assigns.current_note || %DeliveryNote{}, params)

    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"delivery_note" => params}, socket) do
    result =
      case socket.assigns.current_note do
        nil -> Finance.create_delivery_note(params, socket.assigns.current_user)
        note -> Finance.update_delivery_note(note, params, socket.assigns.current_user)
      end

    case result do
      {:ok, _note} ->
        {:noreply,
         socket
         |> put_flash(:info, "Delivery note saved.")
         |> assign(:form_modal_open, false)
         |> load_notes()
         |> reset_form()}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
    end
  end

  defp load_notes(socket) do
    filters =
      if socket.assigns.status_filter == "",
        do: %{},
        else: %{"status" => socket.assigns.status_filter}

    assign(socket, :delivery_notes, Finance.list_delivery_notes(filters))
  end

  defp reset_form(socket) do
    changeset = Finance.change_delivery_note(%DeliveryNote{}, %{"items" => [%{}]})
    assign(socket, :form, to_form(changeset))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-8">
      <div class="flex items-center justify-between gap-4">
        <h1 class="page-title">Delivery notes</h1>
        <button
          type="button"
          phx-click="open_form_modal"
          class="bg-green-700 hover:bg-green-800 text-white text-sm font-medium px-4 py-2 rounded-lg"
        >
          New delivery note
        </button>
      </div>
      <.finance_subnav current={:delivery_notes} />

      <form phx-change="filter" class="flex items-center gap-3">
        <.label for="status">Status</.label>
        <select name="status" class="rounded-lg border border-zinc-300 text-sm">
          <option value="">All</option>
          <option
            :for={value <- Ecto.Enum.values(DeliveryNote, :status)}
            value={value}
            selected={@status_filter == to_string(value)}
          >
            {Phoenix.Naming.humanize(value)}
          </option>
        </select>
      </form>

      <div class="panel-shell">
        <div class="overflow-x-auto">
          <table class="data-table">
            <thead>
              <tr>
                <th>Order ref</th>
                <th>Client</th>
                <th>Dispatched on</th>
                <th>Status</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={note <- @delivery_notes}>
                <td>{note.order_reference}</td>
                <td>{note.client.name}</td>
                <td>{format_date(note.dispatched_on)}</td>
                <td><.finance_badge status={note.status} /></td>
                <td class="text-right">
                  <button type="button" phx-click="edit" phx-value-id={note.id} class="action-link">
                    Edit
                  </button>
                </td>
              </tr>
              <tr :if={Enum.empty?(@delivery_notes)}>
                <td colspan="5" class="text-center text-sm text-zinc-400">
                  No delivery notes found.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <.modal
        :if={@form_modal_open}
        id="delivery-note-form-modal"
        show
        on_cancel={JS.push("close_form_modal")}
      >
        <div class="space-y-6">
          <h2 class="section-heading">{modal_title(@current_note)}</h2>

          <.form
            for={@form}
            id="delivery-note-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-5"
          >
            <.input field={@form[:order_reference]} type="text" label="Order reference" required />
            <.input
              field={@form[:client_id]}
              type="select"
              label="Client"
              options={@clients}
              prompt="Choose a client"
              required
            />
            <.input field={@form[:dispatched_on]} type="date" label="Dispatched on" />
            <.input field={@form[:signed_by]} type="text" label="Signed by" />
            <.input
              field={@form[:status]}
              type="select"
              label="Status"
              options={enum_options(DeliveryNote, :status)}
              required
            />

            <div>
              <h3 class="text-sm font-medium text-zinc-600">Items</h3>

              <div class="mt-3 space-y-3">
                <.inputs_for :let={item_form} field={@form[:items]}>
                  <div class="grid grid-cols-12 gap-3 items-end rounded-lg border border-zinc-200 p-4">
                    <input type="hidden" name="delivery_note[items_sort][]" value={item_form.index} />
                    <div class="col-span-5">
                      <.input field={item_form[:product]} type="text" label="Product" />
                    </div>
                    <div class="col-span-3">
                      <.input
                        field={item_form[:quantity_mt]}
                        type="number"
                        step="any"
                        label="Quantity (MT)"
                      />
                    </div>
                    <div class="col-span-3">
                      <.input field={item_form[:unit]} type="text" label="Unit" />
                    </div>
                    <div class="col-span-1">
                      <label class="flex items-center gap-2 text-xs text-zinc-500">
                        <input
                          type="checkbox"
                          name="delivery_note[items_drop][]"
                          value={item_form.index}
                        /> Remove
                      </label>
                    </div>
                  </div>
                </.inputs_for>

                <input type="hidden" name="delivery_note[items_drop][]" />

                <button
                  type="button"
                  name="delivery_note[items_sort][]"
                  value="new"
                  phx-click={JS.dispatch("change", to: "#delivery-note-form")}
                  class="action-link"
                >
                  + Add item
                </button>
              </div>
            </div>

            <div class="flex items-center justify-between gap-4">
              <button type="button" phx-click="close_form_modal" class="nav-chip">Cancel</button>
              <.button class="bg-green-700 hover:bg-green-800">{submit_label(@current_note)}</.button>
            </div>
          </.form>
        </div>
      </.modal>
    </section>
    """
  end

  defp enum_options(schema, field) do
    schema
    |> Ecto.Enum.values(field)
    |> Enum.map(&{Phoenix.Naming.humanize(&1), &1})
  end

  defp modal_title(nil), do: "New delivery note"
  defp modal_title(_note), do: "Edit delivery note"

  defp submit_label(nil), do: "Create delivery note"
  defp submit_label(_note), do: "Save changes"

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")
  defp format_date(_), do: "-"
end
