defmodule ChasingSunWeb.InvoicesLive.New do
  use ChasingSunWeb, :live_view

  alias ChasingSun.Accounts.Scope
  alias ChasingSun.Finance
  alias ChasingSun.Finance.Invoice

  @impl true
  def mount(_params, _session, socket) do
    if not Scope.can?(socket.assigns.current_user, :manage_finance) do
      {:ok,
       socket
       |> put_flash(:error, "Only accountants and admins can create invoices.")
       |> redirect(to: ~p"/finance/invoices")}
    else
      mount_form(socket)
    end
  end

  defp mount_form(socket) do
    changeset = Finance.change_invoice(%Invoice{}, %{"line_items" => [%{}]})

    {:ok,
     socket
     |> assign(:page_title, "New invoice")
     |> assign(:clients, Finance.client_options())
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"invoice" => params}, socket) do
    changeset = Finance.change_invoice(%Invoice{}, params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"invoice" => params}, socket) do
    case Finance.create_invoice(params, socket.assigns.current_user) do
      {:ok, invoice} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invoice #{invoice.invoice_number} created.")
         |> push_navigate(to: ~p"/finance/invoices/#{invoice.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-8">
      <h1 class="page-title">New invoice</h1>
      <.finance_subnav current={:invoices} />

      <div class="panel-shell max-w-3xl">
        <.form for={@form} id="invoice-form" phx-change="validate" phx-submit="save" class="space-y-6">
          <.input
            field={@form[:client_id]}
            type="select"
            label="Client"
            options={@clients}
            prompt="Choose a client"
            required
          />
          <.input
            field={@form[:business_line]}
            type="select"
            label="Business line"
            options={enum_options(Invoice, :business_line)}
            prompt="Choose a business line"
            required
          />
          <.input field={@form[:due_date]} type="date" label="Due date" required />

          <div>
            <h2 class="section-heading">Line items</h2>

            <div class="mt-4 space-y-4">
              <.inputs_for :let={line_item_form} field={@form[:line_items]}>
                <div class="grid grid-cols-12 gap-3 items-end rounded-lg border border-zinc-200 p-4">
                  <input type="hidden" name="invoice[line_items_sort][]" value={line_item_form.index} />
                  <div class="col-span-5">
                    <.input field={line_item_form[:description]} type="text" label="Description" />
                  </div>
                  <div class="col-span-2">
                    <.input field={line_item_form[:quantity]} type="number" step="any" label="Qty" />
                  </div>
                  <div class="col-span-2">
                    <.input
                      field={line_item_form[:unit_price]}
                      type="number"
                      step="any"
                      label="Unit price"
                    />
                  </div>
                  <div class="col-span-2">
                    <.input
                      field={line_item_form[:total]}
                      type="number"
                      step="any"
                      label="Total"
                      readonly
                    />
                  </div>
                  <div class="col-span-1">
                    <label class="flex items-center gap-2 text-xs text-zinc-500">
                      <input
                        type="checkbox"
                        name="invoice[line_items_drop][]"
                        value={line_item_form.index}
                      /> Remove
                    </label>
                  </div>
                </div>
              </.inputs_for>

              <input type="hidden" name="invoice[line_items_drop][]" />

              <button
                type="button"
                name="invoice[line_items_sort][]"
                value="new"
                phx-click={JS.dispatch("change", to: "#invoice-form")}
                class="action-link"
              >
                + Add line item
              </button>
            </div>
          </div>

          <div class="flex items-center justify-between border-t border-zinc-200 pt-4">
            <span class="text-sm font-medium text-zinc-600">Grand total</span>
            <span class="text-lg font-semibold text-zinc-900">
              {format_currency(grand_total(@form))}
            </span>
          </div>

          <div class="flex items-center justify-end gap-3">
            <.button class="bg-green-700 hover:bg-green-800">Save invoice</.button>
          </div>
        </.form>
      </div>
    </section>
    """
  end

  defp enum_options(schema, field) do
    schema
    |> Ecto.Enum.values(field)
    |> Enum.map(&{Phoenix.Naming.humanize(&1), &1})
  end

  defp grand_total(form) do
    form.source
    |> Ecto.Changeset.get_field(:line_items, [])
    |> Enum.reduce(Decimal.new(0), fn item, acc ->
      Decimal.add(acc, item.total || Decimal.new(0))
    end)
  end
end
