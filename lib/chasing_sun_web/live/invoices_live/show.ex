defmodule ChasingSunWeb.InvoicesLive.Show do
  use ChasingSunWeb, :live_view

  alias ChasingSun.Finance
  alias ChasingSun.Finance.Invoice

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    invoice = Finance.get_invoice!(id)

    {:ok,
     socket
     |> assign(:page_title, "Invoice #{invoice.invoice_number}")
     |> assign(:invoice, invoice)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-6">
      <style>
        @media print {
          .no-print { display: none !important; }
        }
      </style>

      <div class="no-print flex items-center justify-between">
        <h1 class="page-title">Invoice {@invoice.invoice_number}</h1>
        <div class="flex items-center gap-3">
          <.link navigate={~p"/finance/invoices"} class="action-link">Back to invoices</.link>
          <button
            type="button"
            onclick="window.print()"
            class="border border-zinc-300 bg-white text-zinc-700 text-sm font-medium px-4 py-2 rounded-lg"
          >
            Print / Save as PDF
          </button>
        </div>
      </div>

      <div class="panel-shell max-w-3xl">
        <div class="flex items-start justify-between">
          <div>
            <p class="text-lg font-semibold text-zinc-900">ChasingSun</p>
            <p class="text-sm text-zinc-500">Invoice {@invoice.invoice_number}</p>
          </div>
          <.finance_badge status={@invoice.status} />
        </div>

        <div class="mt-6 grid grid-cols-2 gap-6 text-sm">
          <div>
            <p class="text-xs uppercase tracking-wide text-zinc-400">Billed to</p>
            <p class="mt-1 font-medium text-zinc-900">{@invoice.client.name}</p>
            <p class="text-zinc-500">{@invoice.client.contact_person}</p>
            <p class="text-zinc-500">{@invoice.client.email}</p>
            <p class="text-zinc-500">{@invoice.client.phone}</p>
          </div>
          <div class="text-right">
            <p class="text-xs uppercase tracking-wide text-zinc-400">Due date</p>
            <p class="mt-1 font-medium text-zinc-900">{format_date(@invoice.due_date)}</p>
            <p class="mt-4 text-xs uppercase tracking-wide text-zinc-400">Business line</p>
            <p class="font-medium text-zinc-900">{Phoenix.Naming.humanize(@invoice.business_line)}</p>
          </div>
        </div>

        <table class="data-table mt-8">
          <thead>
            <tr>
              <th>Description</th>
              <th>Quantity</th>
              <th>Unit price</th>
              <th>Total</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={item <- @invoice.line_items}>
              <td>{item.description}</td>
              <td>{item.quantity}</td>
              <td>{format_currency(item.unit_price)}</td>
              <td>{format_currency(item.total)}</td>
            </tr>
          </tbody>
        </table>

        <div class="mt-4 flex items-center justify-end gap-4 border-t border-zinc-200 pt-4">
          <span class="text-sm font-medium text-zinc-600">Grand total</span>
          <span class="text-lg font-semibold text-zinc-900">{format_currency(Invoice.total(@invoice))}</span>
        </div>
      </div>
    </section>
    """
  end

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")
  defp format_date(_), do: "-"
end
