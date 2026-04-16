defmodule ChasingSunWeb.Admin.CropRuleLive.Index do
  use ChasingSunWeb, :live_view

  alias ChasingSun.Operations
  alias ChasingSun.Operations.CropRule

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Crop Rules")
     |> assign(:current_rule, nil)
     |> assign(:form_modal_open, false)
     |> load_rules()
     |> reset_form()}
  end

  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    rule = Operations.get_crop_rule!(id)

    {:noreply,
     socket
     |> assign(:current_rule, rule)
     |> assign(:form_modal_open, true)
     |> assign(:rule_form, to_form(Operations.change_crop_rule(rule), as: :crop_rule))}
  end

  def handle_event("new", _params, socket) do
    {:noreply,
     socket
     |> assign(:current_rule, nil)
     |> reset_form()
     |> assign(:form_modal_open, true)}
  end

  def handle_event("close_form_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:current_rule, nil)
     |> assign(:form_modal_open, false)
     |> reset_form()}
  end

  def handle_event("validate", %{"crop_rule" => params}, socket) do
    rule = socket.assigns.current_rule || %CropRule{}
    changeset = Operations.change_crop_rule(rule, params) |> Map.put(:action, :validate)

    {:noreply, assign(socket, :rule_form, to_form(changeset, as: :crop_rule))}
  end

  def handle_event("save", %{"crop_rule" => params}, socket) do
    result =
      case socket.assigns.current_rule do
        nil -> Operations.create_crop_rule(params, socket.assigns.current_user)
        rule -> Operations.update_crop_rule(rule, params, socket.assigns.current_user)
      end

    case result do
      {:ok, _rule} ->
        {:noreply,
         socket
         |> put_flash(:info, "Crop rule saved.")
         |> assign(:current_rule, nil)
         |> load_rules()
         |> reset_form()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:form_modal_open, true)
         |> assign(:rule_form, to_form(Map.put(changeset, :action, :validate), as: :crop_rule))
         |> put_flash(:error, changeset_error_summary(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-6">
      <div class="grid gap-6 xl:grid-cols-[minmax(0,1.45fr)_minmax(320px,1fr)]">
        <div class="panel-shell">
          <p class="eyebrow">Admin Rules</p>
          <h1 class="page-title">Crop planning defaults</h1>

          <p class="page-copy">
            Maintain the baseline durations, yields, and pricing used by forecasting and performance analytics.
          </p>

          <div class="mt-8 grid gap-4 md:grid-cols-3">
            <.summary_card
              title="Configured rules"
              value={length(@rules)}
              hint="Active and inactive crop baselines"
            />
            <.summary_card
              title="Active rules"
              value={Enum.count(@rules, & &1.active)}
              hint="Used by forecasting and planning"
              accent="yellow"
            />
            <.summary_card
              title="Yield models"
              value={
                Enum.count(
                  @rules,
                  &((&1.expected_yield_1000 || 0.0) > 0 or (&1.flat_expected_yield || 0.0) > 0)
                )
              }
              hint="Rules with seeded production logic"
              accent="ink"
            />
          </div>
        </div>

        <div class="panel-shell">
          <p class="eyebrow">Quick Actions</p>
          <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
            Edit rules in popups
          </h2>
          <p class="mt-4 text-sm leading-6 text-[var(--muted)]">
            Keep the rule table visible while opening new and edit forms in a focused modal.
          </p>

          <button
            type="button"
            phx-click="new"
            class="mt-6 inline-flex w-full items-center justify-center rounded-[1.25rem] bg-[var(--brand-green)] px-4 py-3 text-sm font-semibold text-white transition hover:bg-[var(--brand-green-deep)]"
          >
            New rule
          </button>
        </div>
      </div>

      <div class="panel-shell">
        <p class="eyebrow">Rule Table</p>
        <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
          Current forecasting rules
        </h2>

        <div class="mt-6 overflow-x-auto">
          <table class="data-table">
            <thead>
              <tr>
                <th>Crop</th>
                <th>Lead times</th>
                <th>Yield model</th>
                <th>Price</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={rule <- @rules}>
                <td>
                  <p class="font-semibold text-[var(--ink)]">{rule.crop_type}</p>
                  <p class="mt-1 text-xs text-[var(--muted)]">
                    Default: {rule.default_variety || "No default variety"}
                  </p>
                  <p class="mt-1 text-xs text-[var(--muted)]">
                    Varieties: {format_varieties(rule.varieties)}
                  </p>
                </td>
                <td>
                  <p>Nursery: {rule.nursery_days || 0}d</p>
                  <p class="mt-1 text-xs text-[var(--muted)]">
                    Harvest start: {rule.days_to_harvest || 0}d · Duration: {rule.harvest_period_days ||
                      0}d
                  </p>
                </td>
                <td>
                  <p>1000: {format_number(rule.expected_yield_1000 || 0.0, decimals: 1)}</p>
                  <p class="mt-1 text-xs text-[var(--muted)]">
                    2000: {format_number(rule.expected_yield_2000 || 0.0, decimals: 1)} · Flat: {format_number(
                      rule.flat_expected_yield || 0.0,
                      decimals: 1
                    )}
                  </p>
                </td>
                <td>{format_currency(rule.price_per_unit || 0.0, decimals: 1)}</td>
                <td class="text-right">
                  <button type="button" phx-click="edit" phx-value-id={rule.id} class="action-link">
                    Edit
                  </button>
                </td>
              </tr>
              <tr :if={Enum.empty?(@rules)}>
                <td colspan="5" class="text-center text-sm text-[var(--muted)]">
                  No crop rules configured.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <.modal
        :if={@form_modal_open}
        id="crop-rule-form-modal"
        show
        on_cancel={JS.push("close_form_modal")}
      >
        <div class="space-y-6">
          <div>
            <p class="eyebrow">Admin Rules</p>
            <h2 class="mt-3 text-3xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
              {if @current_rule, do: "Edit crop rule", else: "New crop rule"}
            </h2>
          </div>

          <.form for={@rule_form} phx-change="validate" phx-submit="save" class="space-y-4">
            <div class="grid gap-4 md:grid-cols-2">
              <.input field={@rule_form[:crop_type]} label="Crop type" required />
              <.input field={@rule_form[:default_variety]} label="Default variety" />
            </div>

            <.input
              field={@rule_form[:varieties_text]}
              type="textarea"
              label="Varieties"
              placeholder="Add one variety per line or separate with commas"
            />

            <div class="grid gap-4 md:grid-cols-2">
              <.input field={@rule_form[:nursery_days]} type="number" label="Nursery days" />
              <.input field={@rule_form[:days_to_harvest]} type="number" label="Days to harvest" />
            </div>

            <div class="grid gap-4 md:grid-cols-2">
              <.input
                field={@rule_form[:harvest_period_days]}
                type="number"
                label="Harvest period days"
              />
              <.input field={@rule_form[:forced_size]} label="Forced size" />
            </div>

            <div class="grid gap-4 md:grid-cols-2">
              <.input
                field={@rule_form[:expected_yield_1000]}
                type="number"
                step="0.1"
                label="Expected yield 1000"
              />
              <.input
                field={@rule_form[:expected_yield_2000]}
                type="number"
                step="0.1"
                label="Expected yield 2000"
              />
            </div>

            <div class="grid gap-4 md:grid-cols-2">
              <.input
                field={@rule_form[:flat_expected_yield]}
                type="number"
                step="0.1"
                label="Flat expected yield"
              />
              <.input
                field={@rule_form[:price_per_unit]}
                type="number"
                step="0.1"
                label="Price per unit (KES)"
                required
              />
            </div>

            <.input field={@rule_form[:active]} type="checkbox" label="Rule active" />

            <div class="flex items-center justify-between gap-4">
              <button type="button" phx-click="close_form_modal" class="nav-chip">Cancel</button>
              <.button>Save crop rule</.button>
            </div>
          </.form>
        </div>
      </.modal>
    </section>
    """
  end

  defp load_rules(socket) do
    assign(socket, :rules, Operations.list_crop_rules())
  end

  defp reset_form(socket) do
    assign(socket,
      form_modal_open: false,
      rule_form: to_form(Operations.change_crop_rule(%CropRule{}), as: :crop_rule)
    )
  end

  defp changeset_error_summary(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, _opts} -> message end)
    |> Enum.flat_map(fn {field, messages} ->
      Enum.map(messages, &"#{Phoenix.Naming.humanize(field)} #{&1}")
    end)
    |> Enum.join(", ")
  end

  defp format_varieties([]), do: "No varieties configured"
  defp format_varieties(varieties), do: Enum.join(varieties, ", ")
end
