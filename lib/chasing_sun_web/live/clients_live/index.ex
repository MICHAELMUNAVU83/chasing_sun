defmodule ChasingSunWeb.ClientsLive.Index do
  use ChasingSunWeb, :live_view

  alias ChasingSun.Finance
  alias ChasingSun.Finance.Client

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Clients")
     |> assign(:query, "")
     |> assign(:form_modal_open, false)
     |> assign(:current_client, nil)
     |> load_clients()
     |> reset_form()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :form_modal_open, socket.assigns.live_action == :new)}
  end

  @impl true
  def handle_event("filter", %{"query" => query}, socket) do
    {:noreply, socket |> assign(:query, query) |> load_clients()}
  end

  def handle_event("open_form_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:current_client, nil)
     |> reset_form()
     |> assign(:form_modal_open, true)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    client = Finance.get_client!(id)

    {:noreply,
     socket
     |> assign(:current_client, client)
     |> assign(:form, to_form(Finance.change_client(client)))
     |> assign(:form_modal_open, true)}
  end

  def handle_event("close_form_modal", _params, socket) do
    {:noreply, socket |> assign(:form_modal_open, false) |> reset_form()}
  end

  def handle_event("validate", %{"client" => params}, socket) do
    changeset = Finance.change_client(socket.assigns.current_client || %Client{}, params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"client" => params}, socket) do
    result =
      case socket.assigns.current_client do
        nil -> Finance.create_client(params, socket.assigns.current_user)
        client -> Finance.update_client(client, params, socket.assigns.current_user)
      end

    case result do
      {:ok, _client} ->
        {:noreply,
         socket
         |> put_flash(:info, "Client saved.")
         |> assign(:form_modal_open, false)
         |> load_clients()
         |> reset_form()}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
    end
  end

  defp load_clients(socket) do
    filters = if socket.assigns.query == "", do: %{}, else: %{"query" => socket.assigns.query}
    assign(socket, :clients, Finance.list_clients(filters))
  end

  defp reset_form(socket) do
    assign(socket, :form, to_form(Finance.change_client(%Client{})))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-8">
      <div class="flex items-center justify-between gap-4">
        <h1 class="page-title">Clients</h1>
        <button
          type="button"
          phx-click="open_form_modal"
          class="bg-green-700 hover:bg-green-800 text-white text-sm font-medium px-4 py-2 rounded-lg"
        >
          Add client
        </button>
      </div>
      <.finance_subnav current={:clients} />

      <form phx-change="filter" class="flex items-center gap-3">
        <.label for="query">Search</.label>
        <input
          type="text"
          name="query"
          value={@query}
          placeholder="Search by name"
          class="rounded-lg border border-zinc-300 text-sm"
        />
      </form>

      <div class="panel-shell">
        <div class="overflow-x-auto">
          <table class="data-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Type</th>
                <th>Contact person</th>
                <th>Phone</th>
                <th>Email</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={client <- @clients}>
                <td>{client.name}</td>
                <td>{Phoenix.Naming.humanize(client.type)}</td>
                <td>{client.contact_person || "-"}</td>
                <td>{client.phone || "-"}</td>
                <td>{client.email || "-"}</td>
                <td class="text-right">
                  <button type="button" phx-click="edit" phx-value-id={client.id} class="action-link">
                    Edit
                  </button>
                </td>
              </tr>
              <tr :if={Enum.empty?(@clients)}>
                <td colspan="6" class="text-center text-sm text-zinc-400">No clients found.</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <.modal
        :if={@form_modal_open}
        id="client-form-modal"
        show
        on_cancel={JS.push("close_form_modal")}
      >
        <div class="space-y-6">
          <h2 class="section-heading">{modal_title(@current_client)}</h2>

          <.form
            for={@form}
            id="client-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-5"
          >
            <.input field={@form[:name]} type="text" label="Name" required />
            <.input
              field={@form[:type]}
              type="select"
              label="Type"
              options={enum_options(Client, :type)}
              prompt="Choose a type"
              required
            />
            <.input field={@form[:contact_person]} type="text" label="Contact person" />
            <.input field={@form[:phone]} type="text" label="Phone" />
            <.input field={@form[:email]} type="email" label="Email" />

            <div class="flex items-center justify-between gap-4">
              <button type="button" phx-click="close_form_modal" class="nav-chip">Cancel</button>
              <.button class="bg-green-700 hover:bg-green-800">
                {submit_label(@current_client)}
              </.button>
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

  defp modal_title(nil), do: "Add client"
  defp modal_title(_client), do: "Edit client"

  defp submit_label(nil), do: "Create client"
  defp submit_label(_client), do: "Save changes"
end
