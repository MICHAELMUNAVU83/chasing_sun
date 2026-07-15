defmodule ChasingSunWeb.TransactionsLive.Edit do
  use ChasingSunWeb, :live_view

  alias ChasingSun.Accounts.Scope
  alias ChasingSun.Finance
  alias ChasingSun.Finance.Transaction

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if not Scope.can?(socket.assigns.current_user, :manage_finance) do
      {:ok,
       socket
       |> put_flash(:error, "Only accountants and admins can edit transactions.")
       |> redirect(to: ~p"/finance/transactions")}
    else
      mount_form(id, socket)
    end
  end

  defp mount_form(id, socket) do
    transaction = Finance.get_transaction!(id)

    {:ok,
     socket
     |> assign(:page_title, "Edit transaction")
     |> assign(:transaction, transaction)
     |> assign(:clients, Finance.client_options())
     |> assign(:form, to_form(Finance.change_transaction(transaction)))}
  end

  @impl true
  def handle_event("validate", %{"transaction" => params}, socket) do
    changeset = Finance.change_transaction(socket.assigns.transaction, params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"transaction" => params}, socket) do
    case Finance.update_transaction(
           socket.assigns.transaction,
           params,
           socket.assigns.current_user
         ) do
      {:ok, _transaction} ->
        {:noreply,
         socket
         |> put_flash(:info, "Transaction updated.")
         |> push_navigate(to: ~p"/finance/transactions")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
    end
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/finance/transactions")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-8">
      <h1 class="page-title">Edit transaction</h1>

      <div class="panel-shell max-w-2xl">
        <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-5">
          <.input
            field={@form[:type]}
            type="select"
            label="Type"
            options={enum_options(Transaction, :type)}
            required
          />
          <.input
            field={@form[:business_line]}
            type="select"
            label="Business line"
            options={enum_options(Transaction, :business_line)}
            required
          />
          <.input field={@form[:amount]} type="number" step="any" label="Amount (KES)" required />
          <.input field={@form[:occurred_on]} type="date" label="Date" required />
          <.input
            field={@form[:client_id]}
            type="select"
            label="Client"
            options={@clients}
            prompt="No client"
          />
          <.input field={@form[:category]} type="text" label="Category" />
          <.input field={@form[:description]} type="text" label="Description" />

          <div class="flex items-center justify-between gap-4">
            <button type="button" phx-click="cancel" class="nav-chip">Cancel</button>
            <.button class="bg-green-700 hover:bg-green-800">Save changes</.button>
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
end
