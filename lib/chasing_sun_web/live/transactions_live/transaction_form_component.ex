defmodule ChasingSunWeb.TransactionsLive.TransactionFormComponent do
  use ChasingSunWeb, :live_component

  alias ChasingSun.Finance
  alias ChasingSun.Finance.Transaction

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, to_form(Finance.change_transaction(%Transaction{})))}
  end

  @impl true
  def handle_event("validate", %{"transaction" => params}, socket) do
    changeset = Finance.change_transaction(%Transaction{}, params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"transaction" => params}, socket) do
    case Finance.create_transaction(params, socket.assigns.current_user) do
      {:ok, transaction} ->
        send(self(), {:transaction_saved, transaction})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <h2 class="section-heading">New transaction</h2>

      <.form for={@form} phx-target={@myself} phx-change="validate" phx-submit="save" class="space-y-5">
        <.input field={@form[:type]} type="select" label="Type" options={enum_options(Transaction, :type)} prompt="Choose a type" required />
        <.input field={@form[:business_line]} type="select" label="Business line" options={enum_options(Transaction, :business_line)} prompt="Choose a business line" required />
        <.input field={@form[:amount]} type="number" step="any" label="Amount (KES)" required />
        <.input field={@form[:occurred_on]} type="date" label="Date" required />
        <.input field={@form[:client_id]} type="select" label="Client" options={@clients} prompt="No client" />
        <.input field={@form[:category]} type="text" label="Category" placeholder="e.g. seed_cost, transport, sale" />
        <.input field={@form[:description]} type="text" label="Description" />

        <div class="flex items-center justify-end gap-3">
          <.button class="bg-green-700 hover:bg-green-800">Save transaction</.button>
        </div>
      </.form>
    </div>
    """
  end

  defp enum_options(schema, field) do
    schema
    |> Ecto.Enum.values(field)
    |> Enum.map(&{Phoenix.Naming.humanize(&1), &1})
  end
end
