defmodule ChasingSunWeb.Components.FinanceNav do
  use Phoenix.Component
  use ChasingSunWeb, :verified_routes

  attr :current, :atom, required: true

  def finance_subnav(assigns) do
    assigns = assign(assigns, :tabs, tabs())

    ~H"""
    <nav class="flex flex-wrap gap-2">
      <.link
        :for={tab <- @tabs}
        navigate={tab.path}
        class={["filter-tab", @current == tab.key && "filter-tab-active"]}
      >
        {tab.label}
      </.link>
    </nav>
    """
  end

  defp tabs do
    [
      %{key: :dashboard, label: "Dashboard", path: ~p"/finance"},
      %{key: :transactions, label: "Transactions", path: ~p"/finance/transactions"},
      %{key: :invoices, label: "Invoices", path: ~p"/finance/invoices"},
      %{key: :delivery_notes, label: "Delivery notes", path: ~p"/finance/delivery-notes"},
      %{key: :clients, label: "Clients", path: ~p"/finance/clients"}
    ]
  end
end
