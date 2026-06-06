defmodule ChasingSunWeb.Admin.GuestLive.Index do
  use ChasingSunWeb, :live_view

  alias ChasingSun.Accounts
  alias ChasingSun.Accounts.{Scope, User}
  alias ChasingSun.Operations

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Guest Accounts")
     |> assign(:ventures, Operations.list_ventures())
     |> assign(:current_guest, nil)
     |> assign(:form_modal_open, false)
     |> load_guests()
     |> reset_form()}
  end

  @impl true
  def handle_event("new", _params, socket) do
    {:noreply,
     socket
     |> assign(:current_guest, nil)
     |> reset_form()
     |> assign(:form_modal_open, true)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    guest = Accounts.get_guest_user!(id)

    {:noreply,
     socket
     |> assign(:current_guest, guest)
     |> assign(:form_modal_open, true)
     |> assign(:selected_pages, MapSet.new(guest.allowed_pages || []))
     |> assign(:selected_sections, MapSet.new(guest.allowed_sections || []))
     |> assign(:selected_ventures, MapSet.new(guest.allowed_venture_codes || []))
     |> assign(:guest_form, to_form(Accounts.change_guest_user(guest), as: :guest))}
  end

  def handle_event("close_form_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:current_guest, nil)
     |> assign(:form_modal_open, false)
     |> reset_form()}
  end

  def handle_event("validate", %{"guest" => params}, socket) do
    params = normalize(params)
    guest = socket.assigns.current_guest || %User{}

    changeset =
      guest
      |> Accounts.change_guest_user(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:guest_form, to_form(changeset, as: :guest))
     |> put_selected(params)}
  end

  def handle_event("save", %{"guest" => params}, socket) do
    params = normalize(params)

    result =
      case socket.assigns.current_guest do
        nil -> Accounts.create_guest_user(params)
        guest -> Accounts.update_guest_user(guest, params)
      end

    case result do
      {:ok, _guest} ->
        {:noreply,
         socket
         |> put_flash(:info, "Guest account saved.")
         |> assign(:current_guest, nil)
         |> load_guests()
         |> reset_form()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:form_modal_open, true)
         |> assign(:guest_form, to_form(Map.put(changeset, :action, :validate), as: :guest))
         |> put_selected(params)
         |> put_flash(:error, changeset_error_summary(changeset))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    guest = Accounts.get_guest_user!(id)
    {:ok, _} = Accounts.delete_user(guest)

    {:noreply,
     socket
     |> put_flash(:info, "Guest account removed.")
     |> load_guests()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-6">
      <div class="grid gap-6 xl:grid-cols-[minmax(0,1.45fr)_minmax(320px,1fr)]">
        <div class="panel-shell">
          <p class="eyebrow">Admin Access Control</p>
          <h1 class="page-title">Guest accounts</h1>

          <p class="page-copy">
            Create read-only guest logins and choose exactly what each one sees — which
            dashboard sections, which extra pages, and which ventures. Guests never see
            revenue, performance, or management pages.
          </p>

          <div class="mt-8 grid gap-4 md:grid-cols-2">
            <.summary_card
              title="Guest accounts"
              value={length(@guests)}
              hint="Read-only logins you have created"
            />
            <.summary_card
              title="Configurable sections"
              value={length(Scope.guest_sections())}
              hint="Dashboard panels you can show or hide"
              accent="yellow"
            />
          </div>
        </div>

        <div class="panel-shell">
          <p class="eyebrow">Quick Actions</p>
          <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
            Add a guest login
          </h2>
          <p class="mt-4 text-sm leading-6 text-[var(--muted)]">
            Set an email and password, then tick what the guest is allowed to view.
          </p>

          <button
            type="button"
            phx-click="new"
            class="mt-6 inline-flex w-full items-center justify-center rounded-[1.25rem] bg-[var(--brand-green)] px-4 py-3 text-sm font-semibold text-white transition hover:bg-[var(--brand-green-deep)]"
          >
            New guest account
          </button>
        </div>
      </div>

      <div class="panel-shell">
        <p class="eyebrow">Guest Table</p>
        <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
          Current guest accounts
        </h2>

        <div class="mt-6 overflow-x-auto">
          <table class="data-table">
            <thead>
              <tr>
                <th>Email</th>
                <th>Dashboard sections</th>
                <th>Extra pages</th>
                <th>Ventures</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={guest <- @guests}>
                <td>
                  <p class="font-semibold text-[var(--ink)]">{guest.email}</p>
                </td>
                <td>
                  <p class="text-sm text-[var(--ink)]">
                    {section_summary(guest)}
                  </p>
                </td>
                <td>
                  <p class="text-sm text-[var(--ink)]">{page_summary(guest)}</p>
                </td>
                <td>
                  <p class="text-sm text-[var(--ink)]">{venture_summary(guest)}</p>
                </td>
                <td class="text-right">
                  <button
                    type="button"
                    phx-click="edit"
                    phx-value-id={guest.id}
                    class="action-link mr-4"
                  >
                    Edit
                  </button>
                  <button
                    type="button"
                    phx-click="delete"
                    phx-value-id={guest.id}
                    data-confirm="Remove this guest account? They will no longer be able to log in."
                    class="action-link text-rose-700"
                  >
                    Delete
                  </button>
                </td>
              </tr>
              <tr :if={Enum.empty?(@guests)}>
                <td colspan="5" class="text-center text-sm text-[var(--muted)]">
                  No guest accounts yet.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <.modal
        :if={@form_modal_open}
        id="guest-form-modal"
        show
        on_cancel={JS.push("close_form_modal")}
      >
        <div class="space-y-6">
          <div>
            <p class="eyebrow">Admin Access Control</p>
            <h2 class="mt-3 text-3xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
              {if @current_guest, do: "Edit guest account", else: "New guest account"}
            </h2>
          </div>

          <.form for={@guest_form} phx-change="validate" phx-submit="save" class="space-y-5">
            <.input field={@guest_form[:email]} type="email" label="Email" required />

            <.input
              field={@guest_form[:password]}
              type="password"
              label="Password"
              required={is_nil(@current_guest)}
              placeholder={
                if @current_guest, do: "Leave blank to keep current password", else: nil
              }
            />

            <.toggle_group
              title="Extra pages"
              hint="The dashboard is always available. Tick any read-only pages to also grant."
              field="allowed_pages"
              options={Scope.guest_pages()}
              selected={@selected_pages}
            />

            <.toggle_group
              title="Dashboard sections"
              hint="Choose which panels this guest sees on the dashboard."
              field="allowed_sections"
              options={Scope.guest_sections()}
              selected={@selected_sections}
            />

            <.toggle_group
              title="Ventures"
              hint="Leave all unticked to show every venture, or pick specific ones."
              field="allowed_venture_codes"
              options={Enum.map(@ventures, &%{key: &1.code, label: &1.name})}
              selected={@selected_ventures}
            />

            <div class="flex items-center justify-between gap-4">
              <button type="button" phx-click="close_form_modal" class="nav-chip">Cancel</button>
              <.button>Save guest account</.button>
            </div>
          </.form>
        </div>
      </.modal>
    </section>
    """
  end

  attr :title, :string, required: true
  attr :hint, :string, required: true
  attr :field, :string, required: true
  attr :options, :list, required: true
  attr :selected, :any, required: true

  defp toggle_group(assigns) do
    ~H"""
    <fieldset class="rounded-[1.25rem] border border-[var(--line)] bg-[var(--surface-soft)] p-4">
      <legend class="px-1 text-sm font-semibold text-[var(--ink)]">{@title}</legend>
      <p class="mt-1 text-xs text-[var(--muted)]">{@hint}</p>

      <input type="hidden" name={"guest[#{@field}][]"} value="" />
      <div class="mt-3 grid gap-2 sm:grid-cols-2">
        <label
          :for={option <- @options}
          class="flex items-center gap-2 rounded-xl border border-[var(--line)] bg-white/70 px-3 py-2 text-sm text-[var(--ink)]"
        >
          <input
            type="checkbox"
            name={"guest[#{@field}][]"}
            value={option.key}
            checked={MapSet.member?(@selected, option.key)}
            class="h-4 w-4 rounded border-[var(--line)] text-[var(--brand-green)]"
          />
          {option.label}
        </label>
        <p :if={Enum.empty?(@options)} class="text-sm text-[var(--muted)]">
          Nothing configured yet.
        </p>
      </div>
    </fieldset>
    """
  end

  defp load_guests(socket) do
    assign(socket, :guests, Accounts.list_guest_users())
  end

  defp reset_form(socket) do
    assign(socket,
      form_modal_open: false,
      selected_pages: MapSet.new(),
      selected_sections: MapSet.new(Scope.guest_section_keys()),
      selected_ventures: MapSet.new(),
      guest_form: to_form(Accounts.change_guest_user(%User{}), as: :guest)
    )
  end

  defp put_selected(socket, params) do
    socket
    |> assign(:selected_pages, MapSet.new(Map.get(params, "allowed_pages", [])))
    |> assign(:selected_sections, MapSet.new(Map.get(params, "allowed_sections", [])))
    |> assign(:selected_ventures, MapSet.new(Map.get(params, "allowed_venture_codes", [])))
  end

  # Drop the blank sentinel value emitted by the hidden inputs so empty groups
  # become an empty list rather than [""].
  defp normalize(params) do
    Enum.reduce(["allowed_pages", "allowed_sections", "allowed_venture_codes"], params, fn key,
                                                                                           acc ->
      case Map.get(acc, key) do
        values when is_list(values) -> Map.put(acc, key, Enum.reject(values, &(&1 == "")))
        _ -> acc
      end
    end)
  end

  defp section_summary(%{allowed_sections: []}), do: "None"

  defp section_summary(%{allowed_sections: sections}) do
    all = Scope.guest_section_keys()

    if Enum.sort(sections) == Enum.sort(all) do
      "All sections"
    else
      "#{length(sections)} of #{length(all)}"
    end
  end

  defp page_summary(%{allowed_pages: []}), do: "Dashboard only"

  defp page_summary(%{allowed_pages: pages}) do
    labels =
      Scope.guest_pages()
      |> Enum.filter(&(&1.key in pages))
      |> Enum.map(& &1.label)

    ["Dashboard" | labels] |> Enum.join(", ")
  end

  defp venture_summary(%{allowed_venture_codes: []}), do: "All ventures"
  defp venture_summary(%{allowed_venture_codes: codes}), do: Enum.join(codes, ", ")

  defp changeset_error_summary(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, _opts} -> message end)
    |> Enum.flat_map(fn {field, messages} ->
      Enum.map(messages, &"#{Phoenix.Naming.humanize(field)} #{&1}")
    end)
    |> Enum.join(", ")
  end
end
