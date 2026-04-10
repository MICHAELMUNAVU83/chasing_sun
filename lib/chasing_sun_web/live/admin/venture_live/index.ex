defmodule ChasingSunWeb.Admin.VentureLive.Index do
  use ChasingSunWeb, :live_view

  alias ChasingSun.Operations
  alias ChasingSun.Operations.Venture

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Ventures")
     |> assign(:current_venture, nil)
     |> assign(:form_modal_open, false)
     |> load_ventures()
     |> reset_form()}
  end

  @impl true
  def handle_event("new", _params, socket) do
    {:noreply,
     socket
     |> assign(:current_venture, nil)
     |> reset_form()
     |> assign(:form_modal_open, true)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    venture = Operations.get_venture!(id)

    {:noreply,
     socket
     |> assign(:current_venture, venture)
     |> assign(:form_modal_open, true)
     |> assign(:venture_form, to_form(Operations.change_venture(venture), as: :venture))}
  end

  def handle_event("close_form_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:current_venture, nil)
     |> assign(:form_modal_open, false)
     |> reset_form()}
  end

  def handle_event("validate", %{"venture" => params}, socket) do
    venture = socket.assigns.current_venture || %Venture{}
    changeset = Operations.change_venture(venture, params) |> Map.put(:action, :validate)

    {:noreply, assign(socket, :venture_form, to_form(changeset, as: :venture))}
  end

  def handle_event("save", %{"venture" => params}, socket) do
    result =
      case socket.assigns.current_venture do
        nil -> Operations.create_venture(params, socket.assigns.current_user)
        venture -> Operations.update_venture(venture, params, socket.assigns.current_user)
      end

    case result do
      {:ok, _venture} ->
        {:noreply,
         socket
         |> put_flash(:info, "Venture saved.")
         |> assign(:current_venture, nil)
         |> load_ventures()
         |> reset_form()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:form_modal_open, true)
         |> assign(:venture_form, to_form(Map.put(changeset, :action, :validate), as: :venture))
         |> put_flash(:error, changeset_error_summary(changeset))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    venture = Operations.get_venture!(id)

    case Operations.delete_venture(venture, socket.assigns.current_user) do
      {:ok, _venture} ->
        {:noreply,
         socket
         |> put_flash(:info, "Venture deleted.")
         |> load_ventures()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, put_flash(socket, :error, changeset_error_summary(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-6">
      <div class="grid gap-6 xl:grid-cols-[minmax(0,1.45fr)_minmax(320px,1fr)]">
        <div class="panel-shell">
          <p class="eyebrow">Admin Master Data</p>
          <h1 class="page-title">Ventures and ownership groups</h1>

          <p class="page-copy">
            Manage the venture records used across greenhouse assignment, filtering, and reporting.
          </p>

          <div class="mt-8 grid gap-4 md:grid-cols-3">
            <.summary_card
              title="Configured ventures"
              value={length(@ventures)}
              hint="Records available for greenhouse assignment"
            />
            <.summary_card
              title="Assigned units"
              value={Enum.reduce(@ventures, 0, &(length(&1.greenhouses) + &2))}
              hint="Greenhouses linked to ventures"
              accent="yellow"
            />
            <.summary_card
              title="In active use"
              value={Enum.count(@ventures, &(length(&1.greenhouses) > 0))}
              hint="Ventures currently referenced by greenhouses"
              accent="ink"
            />
          </div>
        </div>

        <div class="panel-shell">
          <p class="eyebrow">Quick Actions</p>
          <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
            Edit ventures in popups
          </h2>
          <p class="mt-4 text-sm leading-6 text-[var(--muted)]">
            Add new venture groups or rename existing ones without leaving the admin workspace.
          </p>

          <button
            type="button"
            phx-click="new"
            class="mt-6 inline-flex w-full items-center justify-center rounded-[1.25rem] bg-[var(--brand-green)] px-4 py-3 text-sm font-semibold text-white transition hover:bg-[var(--brand-green-deep)]"
          >
            New venture
          </button>
        </div>
      </div>

      <div class="panel-shell">
        <p class="eyebrow">Venture Table</p>
        <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
          Current venture records
        </h2>

        <div class="mt-6 overflow-x-auto">
          <table class="data-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Code</th>
                <th>Assigned greenhouses</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={venture <- @ventures}>
                <td>
                  <p class="font-semibold text-[var(--ink)]">{venture.name}</p>
                </td>
                <td>
                  <p class="font-mono text-sm text-[var(--ink)]">{venture.code}</p>
                </td>
                <td>
                  <p class="font-semibold text-[var(--ink)]">{length(venture.greenhouses)}</p>
                  <p class="mt-1 text-xs text-[var(--muted)]">
                    {assigned_greenhouse_hint(venture.greenhouses)}
                  </p>
                </td>
                <td class="text-right">
                  <button
                    type="button"
                    phx-click="edit"
                    phx-value-id={venture.id}
                    class="action-link mr-4"
                  >
                    Edit
                  </button>
                  <button
                    type="button"
                    phx-click="delete"
                    phx-value-id={venture.id}
                    data-confirm="Delete this venture? This only works when no greenhouses still reference it."
                    class="action-link text-rose-700"
                  >
                    Delete
                  </button>
                </td>
              </tr>
              <tr :if={Enum.empty?(@ventures)}>
                <td colspan="4" class="text-center text-sm text-[var(--muted)]">
                  No ventures configured.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <.modal
        :if={@form_modal_open}
        id="venture-form-modal"
        show
        on_cancel={JS.push("close_form_modal")}
      >
        <div class="space-y-6">
          <div>
            <p class="eyebrow">Admin Master Data</p>
            <h2 class="mt-3 text-3xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
              {if @current_venture, do: "Edit venture", else: "New venture"}
            </h2>
          </div>

          <.form for={@venture_form} phx-change="validate" phx-submit="save" class="space-y-4">
            <.input
              field={@venture_form[:name]}
              label="Venture name"
              required
              placeholder="Chasing Sun Core"
            />

            <.input field={@venture_form[:code]} label="Venture code" required placeholder="cs" />

            <p class="rounded-[1.25rem] border border-[var(--line)] bg-[var(--surface-soft)] px-4 py-3 text-sm text-[var(--muted)]">
              Codes are used in filters and URLs. Keep them short, stable, and lowercase.
            </p>

            <div class="flex items-center justify-between gap-4">
              <button type="button" phx-click="close_form_modal" class="nav-chip">Cancel</button>
              <.button>Save venture</.button>
            </div>
          </.form>
        </div>
      </.modal>
    </section>
    """
  end

  defp load_ventures(socket) do
    assign(socket, :ventures, Operations.list_ventures_with_greenhouses())
  end

  defp reset_form(socket) do
    assign(socket,
      form_modal_open: false,
      venture_form: to_form(Operations.change_venture(%Venture{}), as: :venture)
    )
  end

  defp assigned_greenhouse_hint([]), do: "No greenhouse assignments yet"

  defp assigned_greenhouse_hint(greenhouses) do
    greenhouses
    |> Enum.sort_by(& &1.sequence_no)
    |> Enum.take(2)
    |> Enum.map(& &1.name)
    |> Enum.join(" · ")
    |> case do
      "" -> "No greenhouse assignments yet"
      names when length(greenhouses) > 2 -> names <> " and more"
      names -> names
    end
  end

  defp changeset_error_summary(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, _opts} -> message end)
    |> Enum.flat_map(fn {field, messages} ->
      Enum.map(messages, &"#{Phoenix.Naming.humanize(field)} #{&1}")
    end)
    |> Enum.join(", ")
  end
end
