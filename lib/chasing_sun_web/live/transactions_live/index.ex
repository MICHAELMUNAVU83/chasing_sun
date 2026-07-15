defmodule ChasingSunWeb.TransactionsLive.Index do
  use ChasingSunWeb, :live_view

  alias ChasingSun.Finance
  alias ChasingSun.Finance.Transaction

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Transactions")
     |> assign(:filters, %{})
     |> assign(:form_modal_open, false)
     |> assign(:clients, Finance.client_options())
     |> load_transactions()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :form_modal_open, socket.assigns.live_action == :new)}
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters = Map.take(params, ~w(date_from date_to business_line type category client_id))
    {:noreply, socket |> assign(:filters, filters) |> load_transactions()}
  end

  def handle_event("open_add_modal", _params, socket) do
    {:noreply, assign(socket, :form_modal_open, true)}
  end

  def handle_event("close_form_modal", _params, socket) do
    {:noreply, assign(socket, :form_modal_open, false)}
  end

  @impl true
  def handle_info({:transaction_saved, _transaction}, socket) do
    {:noreply,
     socket
     |> assign(:form_modal_open, false)
     |> put_flash(:info, "Transaction saved.")
     |> load_transactions()}
  end

  defp load_transactions(socket) do
    assign(socket, :transactions, Finance.list_transactions(socket.assigns.filters))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-8">
      <div class="flex items-center justify-between gap-4">
        <h1 class="page-title">Transactions</h1>
        <button
          type="button"
          phx-click="open_add_modal"
          class="bg-green-700 hover:bg-green-800 text-white text-sm font-medium px-4 py-2 rounded-lg"
        >
          Add transaction
        </button>
      </div>
      <.finance_subnav current={:transactions} />

      <form phx-change="filter" class="panel-shell flex flex-wrap items-end gap-4">
        <div>
          <.label for="date_from">From</.label>
          <input
            type="date"
            name="date_from"
            value={@filters["date_from"]}
            class="mt-2 block rounded-lg border border-zinc-300 text-sm"
          />
        </div>
        <div>
          <.label for="date_to">To</.label>
          <input
            type="date"
            name="date_to"
            value={@filters["date_to"]}
            class="mt-2 block rounded-lg border border-zinc-300 text-sm"
          />
        </div>
        <div>
          <.label for="business_line">Business line</.label>
          <select name="business_line" class="mt-2 block rounded-lg border border-zinc-300 text-sm">
            <option value="">All</option>
            <option
              :for={value <- enum_values(Transaction, :business_line)}
              value={value}
              selected={@filters["business_line"] == to_string(value)}
            >
              {Phoenix.Naming.humanize(value)}
            </option>
          </select>
        </div>
        <div>
          <.label for="client_id">Client</.label>
          <select name="client_id" class="mt-2 block rounded-lg border border-zinc-300 text-sm">
            <option value="">All</option>
            <option
              :for={{name, id} <- @clients}
              value={id}
              selected={@filters["client_id"] == to_string(id)}
            >
              {name}
            </option>
          </select>
        </div>
      </form>

      <div class="panel-shell">
        <div class="overflow-x-auto">
          <table class="data-table">
            <thead>
              <tr>
                <th>Date</th>
                <th>Type</th>
                <th>Business line</th>
                <th>Amount</th>
                <th>Category</th>
                <th>Client</th>
                <th>Recorded by</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={transaction <- @transactions}>
                <td>{format_date(transaction.occurred_on)}</td>
                <td>{Phoenix.Naming.humanize(transaction.type)}</td>
                <td>{Phoenix.Naming.humanize(transaction.business_line)}</td>
                <td>{format_currency(transaction.amount)}</td>
                <td>{transaction.category || "-"}</td>
                <td>{(transaction.client && transaction.client.name) || "-"}</td>
                <td>
                  <div class="flex items-center justify-between gap-3">
                    <span>{(transaction.recorded_by && transaction.recorded_by.email) || "-"}</span>
                    <.link
                      navigate={~p"/finance/transactions/#{transaction.id}/edit"}
                      class="action-link"
                    >
                      Edit
                    </.link>
                  </div>
                </td>
              </tr>
              <tr :if={Enum.empty?(@transactions)}>
                <td colspan="7" class="text-center text-sm text-zinc-400">
                  No transactions found.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <.modal
        :if={@form_modal_open}
        id="transaction-form-modal"
        show
        on_cancel={JS.push("close_form_modal")}
      >
        <.live_component
          module={ChasingSunWeb.TransactionsLive.TransactionFormComponent}
          id="transaction-form"
          clients={@clients}
          current_user={@current_user}
        />
      </.modal>
    </section>
    """
  end

  defp enum_values(schema, field), do: Ecto.Enum.values(schema, field)

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")
  defp format_date(_), do: "-"
end
