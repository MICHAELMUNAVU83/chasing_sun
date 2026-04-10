defmodule ChasingSunWeb.GreenhouseLive.Index do
  use ChasingSunWeb, :live_view

  alias ChasingSun.Operations
  alias ChasingSun.Operations.{CropCycle, Greenhouse}

  @impl true
  def mount(params, _session, socket) do
    venture_code = params["venture_code"] || "all"

    {:ok,
     socket
     |> assign(:page_title, "Greenhouses")
     |> assign(:current_greenhouse, nil)
     |> assign(:form_modal_open, false)
     |> assign(:crop_types, Operations.crop_types())
     |> load_greenhouses(venture_code)
     |> reset_forms()}
  end

  @impl true
  def handle_event("filter", %{"venture_code" => venture_code}, socket) do
    {:noreply, socket |> load_greenhouses(venture_code) |> reset_forms()}
  end

  def handle_event("open_form_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:current_greenhouse, nil)
     |> reset_forms()
     |> assign(:form_modal_open, true)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    greenhouse = Operations.get_greenhouse!(id)

    {:noreply,
     socket
     |> assign(:current_greenhouse, greenhouse)
     |> assign(:form_modal_open, true)
     |> assign_forms_for_greenhouse(greenhouse)}
  end

  def handle_event("close_form_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:current_greenhouse, nil)
     |> assign(:form_modal_open, false)
     |> reset_forms()}
  end

  def handle_event("save", %{"greenhouse" => greenhouse_params, "cycle" => cycle_params}, socket) do
    if ChasingSunWeb.UserAuth.can?(socket.assigns.current_user, :manage_greenhouses) do
      result =
        case socket.assigns.current_greenhouse do
          nil ->
            Operations.create_greenhouse(
              greenhouse_params,
              cycle_params,
              socket.assigns.current_user
            )

          greenhouse ->
            Operations.update_greenhouse(
              greenhouse,
              greenhouse_params,
              cycle_params,
              socket.assigns.current_user
            )
        end

      case result do
        {:ok, _greenhouse} ->
          message =
            if socket.assigns.current_greenhouse,
              do: "Greenhouse updated.",
              else: "Greenhouse created."

          {:noreply,
           socket
           |> put_flash(:info, message)
           |> assign(:current_greenhouse, nil)
           |> load_greenhouses(socket.assigns.selected_venture)
           |> reset_forms()}

        {:error, %Ecto.Changeset{data: %Greenhouse{}} = changeset} ->
          {:noreply,
           socket
           |> assign(:form_modal_open, true)
           |> assign(
             :greenhouse_form,
             to_form(Map.put(changeset, :action, :validate), as: :greenhouse)
           )
           |> put_flash(:error, changeset_error_summary(changeset))}

        {:error, %Ecto.Changeset{data: %CropCycle{}} = changeset} ->
          {:noreply,
           socket
           |> assign(:form_modal_open, true)
           |> assign(:cycle_form, to_form(Map.put(changeset, :action, :validate), as: :cycle))
           |> put_flash(:error, changeset_error_summary(changeset))}
      end
    else
      {:noreply, put_flash(socket, :error, "You do not have permission to manage greenhouses.")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    if ChasingSunWeb.UserAuth.can?(socket.assigns.current_user, :delete_greenhouses) do
      greenhouse = Operations.get_greenhouse!(id)

      case Operations.delete_greenhouse(greenhouse, socket.assigns.current_user) do
        {:ok, _greenhouse} ->
          {:noreply,
           socket
           |> put_flash(:info, "Greenhouse deleted.")
           |> load_greenhouses(socket.assigns.selected_venture)}

        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, changeset_error_summary(changeset))}
      end
    else
      {:noreply, put_flash(socket, :error, "Only admins can delete greenhouses.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-6">
      <div class="grid gap-6 xl:grid-cols-[minmax(0,1.6fr)_minmax(320px,1fr)]">
        <div class="panel-shell">
          <p class="eyebrow">Estate Registry</p>
          <h1 class="page-title">Greenhouse registry and crop setup</h1>
          <p class="page-copy">
            Add greenhouse units, assign ventures, and register the current crop cycle so the rest of the dashboard can calculate yield and status.
          </p>

          <div class="mt-6 flex flex-wrap gap-2">
            <button
              :for={venture <- filter_options(@ventures)}
              type="button"
              phx-click="filter"
              phx-value-venture_code={venture.code}
              class={filter_tab_class(@selected_venture, venture.code)}
            >
              {venture.label}
            </button>
          </div>

          <div class="mt-8 grid gap-4 md:grid-cols-3">
            <.summary_card
              title="Filtered units"
              value={length(@greenhouses)}
              hint="Visible in this registry view"
            />
            <.summary_card
              title="Active units"
              value={Enum.count(@greenhouses, & &1.active)}
              hint="Currently marked operational"
              accent="yellow"
            />
            <.summary_card
              title="With crop cycles"
              value={Enum.count(@greenhouses, &(Operations.current_cycle(&1) != nil))}
              hint="Ready for analytics and harvest tracking"
              accent="ink"
            />
          </div>
        </div>

        <div class="panel-shell">
          <p class="eyebrow">Quick Actions</p>
          <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
            Register units in a popup flow
          </h2>
          <p class="mt-4 text-sm leading-6 text-[var(--muted)]">
            Keep the registry visible while opening focused modal forms for new greenhouse and cycle setup.
          </p>

          <div class="mt-6 space-y-4">
            <button
              :if={ChasingSunWeb.UserAuth.can?(@current_user, :manage_greenhouses)}
              type="button"
              phx-click="open_form_modal"
              class="inline-flex w-full items-center justify-center rounded-[1.25rem] bg-[var(--brand-green)] px-4 py-3 text-sm font-semibold text-white transition hover:bg-[var(--brand-green-deep)]"
            >
              New greenhouse
            </button>
            <p class="rounded-[1.5rem] border border-[var(--line)] bg-[var(--surface-soft)] px-4 py-4 text-sm text-[var(--muted)]">
              Crop dates auto-fill from crop rules when enough source dates are provided.
            </p>
            <p class="rounded-[1.5rem] border border-dashed border-[var(--line)] px-4 py-4 text-sm text-[var(--muted)]">
              Delete actions remain admin-only and continue to happen inline from the table.
            </p>
          </div>
        </div>
      </div>

      <div class="panel-shell">
        <div class="flex items-center justify-between gap-4">
          <div>
            <p class="eyebrow">Registry</p>
            <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
              Current greenhouse inventory
            </h2>
          </div>
          <p class="text-sm text-[var(--muted)]">Delete actions are restricted to admins.</p>
        </div>

        <div class="mt-6 overflow-x-auto">
          <table class="data-table">
            <thead>
              <tr>
                <th>Unit</th>
                <th>Venture</th>
                <th>Crop cycle</th>
                <th>Status</th>
                <th>Latest harvest</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={greenhouse <- @greenhouses}>
                <td>
                  <p class="font-semibold text-[var(--ink)]">{greenhouse.name}</p>
                  <p class="mt-1 text-xs uppercase tracking-[0.18em] text-[var(--muted)]">
                    Unit {greenhouse.sequence_no} · {greenhouse.size || "size unset"}
                  </p>
                </td>
                <td>
                  <p class="font-semibold text-[var(--ink)]">{greenhouse.venture.name}</p>
                  <p class="mt-1 text-xs uppercase tracking-[0.18em] text-[var(--muted)]">
                    {greenhouse.venture.code}
                  </p>
                </td>
                <td>
                  <%= case Operations.current_cycle(greenhouse) do %>
                    <% nil -> %>
                      <p>No active cycle</p>
                      <p class="mt-1 text-xs text-[var(--muted)]">
                        Register a crop to enable forecasting
                      </p>
                    <% cycle -> %>
                      <p class="font-semibold text-[var(--ink)]">{cycle.crop_type}</p>
                      <p class="mt-1 text-xs text-[var(--muted)]">
                        {cycle.variety || "Variety pending"} · {cycle.plant_count || 0} plants
                      </p>
                  <% end %>
                </td>
                <td>
                  <.status_badge status={
                    Operations.current_cycle(greenhouse) &&
                      Operations.current_cycle(greenhouse).status_cache
                  } />
                </td>
                <td>
                  <%= case List.first(greenhouse.harvest_records) do %>
                    <% nil -> %>
                      <p class="text-[var(--muted)]">No harvest data</p>
                    <% record -> %>
                      <p class="font-semibold text-[var(--ink)]">{format_number(record.actual_yield, decimals: 1)}</p>
                      <p class="mt-1 text-xs text-[var(--muted)]">
                        {format_date(record.week_ending_on)}
                      </p>
                  <% end %>
                </td>
                <td class="text-right">
                  <button
                    :if={ChasingSunWeb.UserAuth.can?(@current_user, :manage_greenhouses)}
                    type="button"
                    phx-click="edit"
                    phx-value-id={greenhouse.id}
                    class="action-link mr-4"
                  >
                    Edit
                  </button>
                  <button
                    :if={ChasingSunWeb.UserAuth.can?(@current_user, :delete_greenhouses)}
                    type="button"
                    phx-click="delete"
                    phx-value-id={greenhouse.id}
                    class="action-link text-rose-700 hover:text-rose-800"
                  >
                    Delete
                  </button>
                </td>
              </tr>
              <tr :if={Enum.empty?(@greenhouses)}>
                <td colspan="6" class="text-center text-sm text-[var(--muted)]">
                  No greenhouses found for the current filter.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <.modal
        :if={@form_modal_open}
        id="greenhouse-form-modal"
        show
        on_cancel={JS.push("close_form_modal")}
      >
        <div class="space-y-6">
          <div>
            <p class="eyebrow">{modal_eyebrow(@current_greenhouse)}</p>
            <h2 class="mt-3 text-3xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
              {modal_title(@current_greenhouse)}
            </h2>
          </div>

          <.form for={@greenhouse_form} phx-submit="save" class="space-y-5">
            <div class="grid gap-4 md:grid-cols-2">
              <.input
                field={@greenhouse_form[:sequence_no]}
                type="number"
                label="Sequence no"
                required
              />
              <.input
                field={@greenhouse_form[:venture_id]}
                type="select"
                label="Venture"
                options={venture_options(@ventures)}
                required
              />
            </div>

            <.input field={@greenhouse_form[:name]} label="Greenhouse name" required />

            <div class="grid gap-4 md:grid-cols-2">
              <.input field={@greenhouse_form[:size]} label="Size" placeholder="1000 plants" />
              <.input field={@greenhouse_form[:tank]} label="Tank" placeholder="A1" />
            </div>

            <.input field={@greenhouse_form[:active]} type="checkbox" label="Active unit" />

            <div class="rounded-[1.5rem] border border-[var(--line)] bg-[var(--surface-soft)] p-4">
              <p class="text-sm font-semibold uppercase tracking-[0.18em] text-[var(--muted)]">
                Optional current crop cycle
              </p>
              <div class="mt-4 space-y-4">
                <div class="grid gap-4 md:grid-cols-2">
                  <.input
                    field={@cycle_form[:crop_type]}
                    type="select"
                    label="Crop type"
                    prompt="Choose crop"
                    options={crop_type_options(@crop_types)}
                  />
                  <.input field={@cycle_form[:variety]} label="Variety" />
                </div>

                <div class="grid gap-4 md:grid-cols-2">
                  <.input field={@cycle_form[:plant_count]} type="number" label="Plant count" />
                  <.input field={@cycle_form[:nursery_date]} type="date" label="Nursery date" />
                </div>

                <div class="grid gap-4 md:grid-cols-2">
                  <.input field={@cycle_form[:transplant_date]} type="date" label="Transplant date" />
                  <.input
                    field={@cycle_form[:harvest_start_date]}
                    type="date"
                    label="Harvest start date"
                  />
                </div>

                <div class="grid gap-4 md:grid-cols-2">
                  <.input field={@cycle_form[:harvest_end_date]} type="date" label="Harvest end date" />
                  <.input
                    field={@cycle_form[:soil_recovery_end_date]}
                    type="date"
                    label="Soil recovery end date"
                  />
                </div>
              </div>
            </div>

            <div class="flex items-center justify-between gap-4">
              <button type="button" phx-click="close_form_modal" class="nav-chip">Cancel</button>
              <.button>{submit_label(@current_greenhouse)}</.button>
            </div>
          </.form>
        </div>
      </.modal>
    </section>
    """
  end

  defp load_greenhouses(socket, venture_code) do
    assign(socket,
      selected_venture: venture_code,
      ventures: Operations.list_ventures(),
      greenhouses: Operations.list_greenhouses(filters_for(venture_code))
    )
  end

  defp reset_forms(socket) do
    assign(socket,
      form_modal_open: false,
      greenhouse_form: base_greenhouse_form(socket),
      cycle_form: base_cycle_form(socket)
    )
  end

  defp assign_forms_for_greenhouse(socket, greenhouse) do
    cycle = Operations.current_cycle(greenhouse)

    assign(socket,
      greenhouse_form: greenhouse_form_for(greenhouse),
      cycle_form: cycle_form_for(cycle)
    )
  end

  defp base_greenhouse_form(socket) do
    to_form(
      %{
        "sequence_no" => "",
        "name" => "",
        "size" => "",
        "tank" => "",
        "venture_id" => default_venture_id(socket),
        "active" => "true"
      },
      as: :greenhouse
    )
  end

  defp greenhouse_form_for(greenhouse) do
    to_form(
      %{
        "sequence_no" => greenhouse.sequence_no,
        "name" => greenhouse.name,
        "size" => greenhouse.size || "",
        "tank" => greenhouse.tank || "",
        "venture_id" => greenhouse.venture_id,
        "active" => greenhouse.active
      },
      as: :greenhouse
    )
  end

  defp base_cycle_form(_socket) do
    to_form(
      %{
        "crop_type" => "",
        "variety" => "",
        "plant_count" => "",
        "nursery_date" => "",
        "transplant_date" => "",
        "harvest_start_date" => "",
        "harvest_end_date" => "",
        "soil_recovery_end_date" => ""
      },
      as: :cycle
    )
  end

  defp cycle_form_for(nil), do: base_cycle_form(nil)

  defp cycle_form_for(cycle) do
    to_form(
      %{
        "crop_type" => cycle.crop_type || "",
        "variety" => cycle.variety || "",
        "plant_count" => cycle.plant_count || "",
        "nursery_date" => iso_date(cycle.nursery_date),
        "transplant_date" => iso_date(cycle.transplant_date),
        "harvest_start_date" => iso_date(cycle.harvest_start_date),
        "harvest_end_date" => iso_date(cycle.harvest_end_date),
        "soil_recovery_end_date" => iso_date(cycle.soil_recovery_end_date)
      },
      as: :cycle
    )
  end

  defp default_venture_id(socket) do
    socket.assigns.ventures
    |> List.first()
    |> case do
      nil -> ""
      venture -> venture.id
    end
  end

  defp venture_options(ventures), do: Enum.map(ventures, &{&1.name, &1.id})
  defp crop_type_options(crop_types), do: Enum.map(crop_types, &{&1, &1})

  defp filter_options(ventures) do
    [
      %{code: "all", label: "All ventures"}
      | Enum.map(ventures, &%{code: &1.code, label: &1.name})
    ]
  end

  defp filter_tab_class(selected_venture, venture_code) do
    if selected_venture == venture_code, do: "filter-tab filter-tab-active", else: "filter-tab"
  end

  defp filters_for("all"), do: %{}
  defp filters_for(venture_code), do: %{venture_code: venture_code}

  defp changeset_error_summary(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, _opts} -> message end)
    |> Enum.flat_map(fn {field, messages} ->
      Enum.map(messages, &"#{Phoenix.Naming.humanize(field)} #{&1}")
    end)
    |> Enum.join(", ")
  end

  defp modal_eyebrow(nil), do: "New Unit"
  defp modal_eyebrow(_greenhouse), do: "Edit Unit"

  defp modal_title(nil), do: "Register greenhouse"
  defp modal_title(greenhouse), do: "Edit #{greenhouse.name}"

  defp submit_label(nil), do: "Create greenhouse"
  defp submit_label(_greenhouse), do: "Save changes"

  defp iso_date(nil), do: ""
  defp iso_date(%Date{} = date), do: Date.to_iso8601(date)

  defp format_date(nil), do: "-"
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")
end
