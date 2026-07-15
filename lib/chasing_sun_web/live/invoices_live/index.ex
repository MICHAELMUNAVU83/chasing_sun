defmodule ChasingSunWeb.InvoicesLive.Index do
  use ChasingSunWeb, :live_view

  alias ChasingSun.Accounts.Scope
  alias ChasingSun.Finance
  alias ChasingSun.Finance.Invoice

  @impl true
  def mount(_params, _session, socket) do
    Finance.sync_overdue_invoices!()

    {:ok,
     socket
     |> assign(:page_title, "Invoices")
     |> assign(:status_filter, "")
     |> load_invoices()}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply, socket |> assign(:status_filter, status) |> load_invoices()}
  end

  def handle_event("mark_sent", %{"id" => id}, socket) do
    if Scope.can?(socket.assigns.current_user, :manage_finance) do
      invoice = Finance.get_invoice!(id)

      case Finance.update_invoice(invoice, %{"status" => "sent"}, socket.assigns.current_user) do
        {:ok, _invoice} ->
          {:noreply, socket |> put_flash(:info, "Invoice marked sent.") |> load_invoices()}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Could not update the invoice.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You do not have permission to update invoices.")}
    end
  end

  def handle_event("mark_paid", %{"id" => id}, socket) do
    if Scope.can?(socket.assigns.current_user, :manage_finance) do
      invoice = Finance.get_invoice!(id)

      case Finance.mark_invoice_paid(invoice, socket.assigns.current_user) do
        {:ok, _invoice, auto_created_transaction?: true} ->
          {:noreply,
           socket
           |> put_flash(:info, "Invoice marked paid. A revenue transaction was recorded.")
           |> load_invoices()}

        {:ok, _invoice, auto_created_transaction?: false} ->
          {:noreply, socket |> put_flash(:info, "Invoice marked paid.") |> load_invoices()}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Could not mark the invoice paid.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You do not have permission to update invoices.")}
    end
  end

  defp load_invoices(socket) do
    filters =
      if socket.assigns.status_filter == "",
        do: %{},
        else: %{"status" => socket.assigns.status_filter}

    assign(socket, :invoices, Finance.list_invoices(filters))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-8">
      <div class="flex items-center justify-between gap-4">
        <h1 class="page-title">Invoices</h1>
        <.link
          navigate={~p"/finance/invoices/new"}
          class="bg-green-700 hover:bg-green-800 text-white text-sm font-medium px-4 py-2 rounded-lg"
        >
          Generate invoice
        </.link>
      </div>
      <.finance_subnav current={:invoices} />

      <form phx-change="filter" class="flex items-center gap-3">
        <.label for="status">Status</.label>
        <select name="status" class="rounded-lg border border-zinc-300 text-sm">
          <option value="">All</option>
          <option
            :for={value <- Ecto.Enum.values(Invoice, :status)}
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
                <th>Invoice #</th>
                <th>Client</th>
                <th>Due date</th>
                <th>Total</th>
                <th>Status</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={invoice <- @invoices}>
                <td>{invoice.invoice_number}</td>
                <td>{invoice.client.name}</td>
                <td>{format_date(invoice.due_date)}</td>
                <td>{format_currency(Invoice.total(invoice))}</td>
                <td><.finance_badge status={invoice.status} /></td>
                <td class="text-right">
                  <div class="flex items-center justify-end gap-3">
                    <.link navigate={~p"/finance/invoices/#{invoice.id}"} class="action-link">
                      View
                    </.link>
                    <button
                      :if={Scope.can?(@current_user, :manage_finance) and invoice.status == :draft}
                      type="button"
                      phx-click="mark_sent"
                      phx-value-id={invoice.id}
                      class="action-link"
                    >
                      Mark sent
                    </button>
                    <button
                      :if={
                        Scope.can?(@current_user, :manage_finance) and
                          invoice.status in [:sent, :overdue]
                      }
                      type="button"
                      phx-click="mark_paid"
                      phx-value-id={invoice.id}
                      class="action-link"
                    >
                      Mark paid
                    </button>
                  </div>
                </td>
              </tr>
              <tr :if={Enum.empty?(@invoices)}>
                <td colspan="6" class="text-center text-sm text-zinc-400">No invoices found.</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>
    """
  end

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")
  defp format_date(_), do: "-"
end
