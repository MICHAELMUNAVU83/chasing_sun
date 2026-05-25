defmodule ChasingSunWeb.FarmVisitLive.Index do
  use ChasingSunWeb, :live_view

  alias ChasingSun.Operations
  alias ChasingSun.Operations.{FarmVisitGreenhouseStatus, FarmVisitReport}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Farm Visits")
     |> assign(:current_report, nil)
     |> assign(:form_modal_open, false)
     |> load_greenhouses()
     |> load_reports()
     |> reset_form()}
  end

  @impl true
  def handle_event("open_form_modal", _params, socket) do
    today_report = Operations.get_farm_visit_report_by_date(Date.utc_today())

    socket =
      case today_report do
        nil ->
          socket
          |> assign(:current_report, nil)
          |> assign(:visit_form, base_visit_form(socket))
          |> assign(:status_forms, base_status_forms(socket))

        report ->
          socket
          |> assign(:current_report, report)
          |> assign(:visit_form, report_form_for(report))
          |> assign(:status_forms, report_status_forms(report))
      end

    {:noreply, assign(socket, :form_modal_open, true)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    report = Operations.get_farm_visit_report!(id)

    {:noreply,
     socket
     |> assign(:current_report, report)
     |> assign(:visit_form, report_form_for(report))
     |> assign(:status_forms, report_status_forms(report))
     |> assign(:form_modal_open, true)}
  end

  def handle_event("close_form_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:current_report, nil)
     |> reset_form()}
  end

  def handle_event("form_changed", %{"visit" => visit_params}, socket) do
    normalized_params = normalize_visit_form_params(visit_params)

    {:noreply,
     socket
     |> assign(:visit_form, to_form(top_level_visit_attrs(normalized_params), as: :visit))
     |> assign(:status_forms, Map.get(normalized_params, "greenhouse_statuses", []))}
  end

  def handle_event("save", %{"visit" => visit_params}, socket) do
    if ChasingSunWeb.UserAuth.can?(socket.assigns.current_user, :manage_farm_visits) do
      normalized_params = normalize_visit_form_params(visit_params)

      result =
        case socket.assigns.current_report do
          nil ->
            Operations.upsert_farm_visit_report(normalized_params, socket.assigns.current_user)

          report ->
            Operations.update_farm_visit_report(
              report,
              normalized_params,
              socket.assigns.current_user
            )
        end

      case result do
        {:ok, _report} ->
          message =
            if socket.assigns.current_report,
              do: "Farm visit report updated.",
              else: "Farm visit report saved."

          {:noreply,
           socket
           |> put_flash(:info, message)
           |> assign(:current_report, nil)
           |> load_reports()
           |> reset_form()}

        {:error, %Ecto.Changeset{data: %FarmVisitReport{}} = changeset} ->
          {:noreply,
           socket
           |> assign(:form_modal_open, true)
           |> assign(
             :visit_form,
             to_form(top_level_visit_attrs(normalized_params), as: :visit)
           )
           |> assign(:status_forms, Map.get(normalized_params, "greenhouse_statuses", []))
           |> put_flash(:error, changeset_error_summary(changeset))}
      end
    else
      {:noreply, put_flash(socket, :error, "You do not have permission to save farm visits.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-6">
      <div class="grid gap-6 xl:grid-cols-[minmax(0,1.6fr)_minmax(320px,1fr)]">
        <div class="panel-shell">
          <p class="eyebrow">Daily Visit Log</p>
          <h1 class="page-title">Farm visit reports</h1>
          <p class="page-copy">
            Capture water reserve checks, greenhouse condition, foot bath compliance, and management remarks for each farm visit.
          </p>

          <div class="mt-8 grid gap-4 md:grid-cols-3">
            <.summary_card title="Recent reports" value={length(@reports)} hint="Latest saved visits" />
            <.summary_card
              title="Last visit"
              value={format_date(@latest_report && @latest_report.visited_on)}
              hint={latest_visitor(@latest_report)}
              accent="yellow"
            />
            <.summary_card
              title="Latest issues"
              value={issue_count(@latest_report)}
              hint="Water, health, weeding, or foot bath flags"
              accent="ink"
            />
          </div>
        </div>

        <div class="panel-shell">
          <p class="eyebrow">Quick Actions</p>
          <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
            Record today’s visit
          </h2>
          <p class="mt-4 text-sm leading-6 text-[var(--muted)]">
            The form opens with one observation row for every registered greenhouse.
          </p>

          <div class="mt-6 space-y-4">
            <button
              :if={ChasingSunWeb.UserAuth.can?(@current_user, :manage_farm_visits)}
              type="button"
              phx-click="open_form_modal"
              class="inline-flex w-full items-center justify-center rounded-[1.25rem] bg-[var(--brand-green)] px-4 py-3 text-sm font-semibold text-white transition hover:bg-[var(--brand-green-deep)]"
            >
              New visit report
            </button>
            <p class="rounded-[1.5rem] border border-[var(--line)] bg-[var(--surface-soft)] px-4 py-4 text-sm text-[var(--muted)]">
              One saved report is kept per visit date, so reopening today updates today’s record.
            </p>
          </div>
        </div>
      </div>

      <div class="panel-shell">
        <div class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
          <div>
            <p class="eyebrow">Visit History</p>
            <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
              Saved farm visits
            </h2>
          </div>
          <p class="text-sm text-[var(--muted)]">
            {length(@greenhouses)} greenhouse rows per new report
          </p>
        </div>

        <div class="mt-6 overflow-x-auto">
          <table class="data-table">
            <thead>
              <tr>
                <th>Date</th>
                <th>Visited by</th>
                <th>Water reserve</th>
                <th>Overall status</th>
                <th>Greenhouses</th>
                <th>Remarks</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={report <- @reports}>
                <td>{format_date(report.visited_on)}</td>
                <td>
                  <p class="font-semibold text-[var(--ink)]">{report.visited_by}</p>
                  <p class="mt-1 text-xs text-[var(--muted)]">{signed_by(report)}</p>
                </td>
                <td>
                  <p class="font-semibold text-[var(--ink)]">
                    {tank_level_label(report.reserve_tank_1_level)} / {tank_level_label(
                      report.reserve_tank_2_level
                    )}
                  </p>
                  <p class={compliance_class(report.water_reserve_compliant)}>
                    {compliance_label(report.water_reserve_compliant)}
                  </p>
                </td>
                <td>
                  <span class={overall_status_class(report.overall_status)}>
                    {overall_status_label(report.overall_status)}
                  </span>
                </td>
                <td>{length(report.greenhouse_statuses)}</td>
                <td class="max-w-xs text-[var(--muted)]">{blank_fallback(report.overall_remarks)}</td>
                <td class="text-right">
                  <button
                    :if={ChasingSunWeb.UserAuth.can?(@current_user, :manage_farm_visits)}
                    type="button"
                    phx-click="edit"
                    phx-value-id={report.id}
                    class="action-link"
                  >
                    Edit
                  </button>
                </td>
              </tr>
              <tr :if={Enum.empty?(@reports)}>
                <td colspan="7" class="text-center text-sm text-[var(--muted)]">
                  No farm visit reports have been saved yet.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div :if={@latest_report} class="panel-shell">
        <p class="eyebrow">Latest Visit Detail</p>
        <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
          {format_date(@latest_report.visited_on)} greenhouse observations
        </h2>

        <div class="mt-6 grid gap-4 xl:grid-cols-2">
          <div
            :for={status <- @latest_report.greenhouse_statuses}
            class="rounded-[1.5rem] border border-[var(--line)] bg-[var(--surface-soft)] p-4"
          >
            <div class="flex items-start justify-between gap-4">
              <div>
                <p class="font-semibold text-[var(--ink)]">{status.greenhouse_name}</p>
                <p class="mt-1 text-xs uppercase tracking-[0.18em] text-[var(--muted)]">
                  Unit {status.greenhouse_sequence_no || "-"} · {format_size(status.greenhouse_size)}
                </p>
              </div>
              <span class={compliance_pill_class(status.foot_bath_compliant)}>
                Foot bath {compliance_label(status.foot_bath_compliant)}
              </span>
            </div>

            <div class="mt-4 grid gap-3 text-sm md:grid-cols-3">
              <p>
                <span class="block text-xs uppercase tracking-[0.18em] text-[var(--muted)]">
                  Health
                </span>
                <span class="font-semibold text-[var(--ink)]">
                  {choice_label(status.plant_health)}
                </span>
              </p>
              <p>
                <span class="block text-xs uppercase tracking-[0.18em] text-[var(--muted)]">
                  Weeding
                </span>
                <span class="font-semibold text-[var(--ink)]">
                  {choice_label(status.weeding_status)}
                </span>
              </p>
              <p>
                <span class="block text-xs uppercase tracking-[0.18em] text-[var(--muted)]">
                  Foot bath date
                </span>
                <span class="font-semibold text-[var(--ink)]">
                  {format_date(status.foot_bath_changed_on)}
                </span>
              </p>
            </div>

            <p class="mt-4 text-sm leading-6 text-[var(--muted)]">
              {blank_fallback(status.management_remarks)}
            </p>
          </div>
        </div>
      </div>

      <.modal
        :if={@form_modal_open}
        id="farm-visit-form-modal"
        show
        on_cancel={JS.push("close_form_modal")}
      >
        <div class="space-y-6">
          <div>
            <p class="eyebrow">{modal_eyebrow(@current_report)}</p>
            <h2 class="mt-3 text-3xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
              {modal_title(@current_report)}
            </h2>
          </div>

          <.form for={@visit_form} phx-change="form_changed" phx-submit="save" class="space-y-6">
            <div class="grid gap-4 md:grid-cols-2">
              <.input field={@visit_form[:visited_on]} type="date" label="Visit date" required />
              <.input field={@visit_form[:visited_by]} label="Visited by" required />
            </div>

            <div class="rounded-[1.5rem] border border-[var(--line)] bg-[var(--surface-soft)] p-4">
              <p class="text-sm font-semibold uppercase tracking-[0.18em] text-[var(--muted)]">
                Water reserve status
              </p>
              <div class="mt-4 grid gap-4 md:grid-cols-2">
                <.input
                  field={@visit_form[:reserve_tank_1_level]}
                  type="select"
                  label="Reserve Tank 1"
                  prompt="Choose level"
                  options={tank_level_options()}
                  required
                />
                <.input
                  field={@visit_form[:reserve_tank_2_level]}
                  type="select"
                  label="Reserve Tank 2"
                  prompt="Choose level"
                  options={tank_level_options()}
                  required
                />
              </div>
              <div class="mt-4">
                <.input
                  field={@visit_form[:water_reserve_compliant]}
                  type="checkbox"
                  label="At least 10,000 L reserve available"
                />
              </div>
            </div>

            <div class="space-y-4">
              <p class="text-sm font-semibold uppercase tracking-[0.18em] text-[var(--muted)]">
                Greenhouse status overview
              </p>

              <div :for={{status_form, index} <- Enum.with_index(@status_forms)}>
                <div class="rounded-[1.5rem] border border-[var(--line)] bg-white p-4">
                  <input
                    type="hidden"
                    name={status_field_name(index, "id")}
                    value={status_value(status_form, "id")}
                  />
                  <input
                    type="hidden"
                    name={status_field_name(index, "greenhouse_id")}
                    value={status_value(status_form, "greenhouse_id")}
                  />
                  <input
                    type="hidden"
                    name={status_field_name(index, "greenhouse_sequence_no")}
                    value={status_value(status_form, "greenhouse_sequence_no")}
                  />
                  <input
                    type="hidden"
                    name={status_field_name(index, "greenhouse_name")}
                    value={status_value(status_form, "greenhouse_name")}
                  />
                  <input
                    type="hidden"
                    name={status_field_name(index, "greenhouse_size")}
                    value={status_value(status_form, "greenhouse_size")}
                  />

                  <div class="flex flex-col gap-2 md:flex-row md:items-start md:justify-between">
                    <div>
                      <p class="font-semibold text-[var(--ink)]">
                        {status_value(status_form, "greenhouse_name")}
                      </p>
                      <p class="mt-1 text-xs uppercase tracking-[0.18em] text-[var(--muted)]">
                        Unit {status_value(status_form, "greenhouse_sequence_no") || "-"} · {format_size(
                          status_value(status_form, "greenhouse_size")
                        )}
                      </p>
                    </div>
                    <.input
                      type="checkbox"
                      label="Foot bath compliant"
                      id={status_field_id(index, "foot_bath_compliant")}
                      name={status_field_name(index, "foot_bath_compliant")}
                      value={status_value(status_form, "foot_bath_compliant")}
                    />
                  </div>

                  <div class="mt-4 grid gap-4 md:grid-cols-3">
                    <.input
                      type="select"
                      label="General plant health"
                      prompt="Choose health"
                      options={plant_health_options()}
                      id={status_field_id(index, "plant_health")}
                      name={status_field_name(index, "plant_health")}
                      value={status_value(status_form, "plant_health")}
                      required
                    />
                    <.input
                      type="select"
                      label="Weeding status"
                      prompt="Choose status"
                      options={weeding_status_options()}
                      id={status_field_id(index, "weeding_status")}
                      name={status_field_name(index, "weeding_status")}
                      value={status_value(status_form, "weeding_status")}
                      required
                    />
                    <.input
                      type="date"
                      label="Foot bath last changed"
                      id={status_field_id(index, "foot_bath_changed_on")}
                      name={status_field_name(index, "foot_bath_changed_on")}
                      value={status_value(status_form, "foot_bath_changed_on")}
                    />
                  </div>

                  <div class="mt-4">
                    <.input
                      type="textarea"
                      label="Management practice remarks"
                      id={status_field_id(index, "management_remarks")}
                      name={status_field_name(index, "management_remarks")}
                      value={status_value(status_form, "management_remarks")}
                      rows="3"
                    />
                  </div>
                </div>
              </div>
            </div>

            <div class="rounded-[1.5rem] border border-[var(--line)] bg-[var(--surface-soft)] p-4">
              <div class="grid gap-4 md:grid-cols-2">
                <.input
                  field={@visit_form[:overall_status]}
                  type="select"
                  label="Overall farm status"
                  prompt="Choose status"
                  options={overall_status_options()}
                  required
                />
                <.input field={@visit_form[:sign_off]} label="Sign off" />
              </div>
              <div class="mt-4">
                <.input
                  field={@visit_form[:overall_remarks]}
                  type="textarea"
                  label="Overall remarks"
                  rows="4"
                />
              </div>
            </div>

            <div class="flex items-center justify-between gap-4">
              <button type="button" phx-click="close_form_modal" class="nav-chip">Cancel</button>
              <.button>{submit_label(@current_report)}</.button>
            </div>
          </.form>
        </div>
      </.modal>
    </section>
    """
  end

  defp load_greenhouses(socket) do
    assign(socket, :greenhouses, Operations.list_greenhouses())
  end

  defp load_reports(socket) do
    reports = Operations.list_farm_visit_reports(%{limit: 30})

    assign(socket,
      reports: reports,
      latest_report: List.first(reports)
    )
  end

  defp reset_form(socket) do
    assign(socket,
      form_modal_open: false,
      visit_form: base_visit_form(socket),
      status_forms: base_status_forms(socket)
    )
  end

  defp base_visit_form(socket) do
    to_form(
      %{
        "visited_on" => Date.utc_today() |> Date.to_iso8601(),
        "visited_by" => socket.assigns.current_user.email,
        "reserve_tank_1_level" => "",
        "reserve_tank_2_level" => "",
        "water_reserve_compliant" => "false",
        "overall_status" => "",
        "overall_remarks" => "",
        "sign_off" => ""
      },
      as: :visit
    )
  end

  defp base_status_forms(socket), do: Enum.map(socket.assigns.greenhouses, &status_form_attrs/1)

  defp report_form_for(report) do
    to_form(
      %{
        "visited_on" => iso_date(report.visited_on),
        "visited_by" => report.visited_by || "",
        "reserve_tank_1_level" => report.reserve_tank_1_level || "",
        "reserve_tank_2_level" => report.reserve_tank_2_level || "",
        "water_reserve_compliant" => report.water_reserve_compliant,
        "overall_status" => report.overall_status || "",
        "overall_remarks" => report.overall_remarks || "",
        "sign_off" => report.sign_off || ""
      },
      as: :visit
    )
  end

  defp report_status_forms(report), do: Enum.map(report.greenhouse_statuses, &status_form_attrs/1)

  defp status_form_attrs(%FarmVisitGreenhouseStatus{} = status) do
    %{
      "id" => status.id,
      "greenhouse_id" => status.greenhouse_id || "",
      "greenhouse_sequence_no" => status.greenhouse_sequence_no || "",
      "greenhouse_name" => status.greenhouse_name || "",
      "greenhouse_size" => status.greenhouse_size || "",
      "plant_health" => status.plant_health || "",
      "weeding_status" => status.weeding_status || "",
      "foot_bath_changed_on" => iso_date(status.foot_bath_changed_on),
      "foot_bath_compliant" => status.foot_bath_compliant,
      "management_remarks" => status.management_remarks || ""
    }
  end

  defp status_form_attrs(greenhouse) do
    %{
      "id" => "",
      "greenhouse_id" => greenhouse.id,
      "greenhouse_sequence_no" => greenhouse.sequence_no,
      "greenhouse_name" => greenhouse.name,
      "greenhouse_size" => greenhouse.size || "",
      "plant_health" => "",
      "weeding_status" => "",
      "foot_bath_changed_on" => "",
      "foot_bath_compliant" => "false",
      "management_remarks" => ""
    }
  end

  defp normalize_visit_form_params(params) do
    params
    |> Map.new(fn {key, value} -> {to_string(key), value} end)
    |> Map.update("greenhouse_statuses", [], &normalize_status_form_params/1)
  end

  defp top_level_visit_attrs(params) do
    Map.take(params, [
      "visited_on",
      "visited_by",
      "reserve_tank_1_level",
      "reserve_tank_2_level",
      "water_reserve_compliant",
      "overall_status",
      "overall_remarks",
      "sign_off"
    ])
  end

  defp normalize_status_form_params(statuses) when is_map(statuses) do
    statuses
    |> Enum.sort_by(fn {index, _status} -> status_index(index) end)
    |> Enum.map(fn {_index, status} ->
      Map.new(status, fn {key, value} -> {to_string(key), value} end)
    end)
  end

  defp normalize_status_form_params(statuses) when is_list(statuses), do: statuses
  defp normalize_status_form_params(_statuses), do: []

  defp status_index(index) do
    case Integer.parse(to_string(index)) do
      {parsed_index, ""} -> parsed_index
      _ -> 0
    end
  end

  defp status_field_name(index, field), do: "visit[greenhouse_statuses][#{index}][#{field}]"

  defp status_field_id(index, field), do: "visit_greenhouse_statuses_#{index}_#{field}"

  defp status_value(status, field) do
    Map.get(status, field) || Map.get(status, String.to_atom(field)) || ""
  end

  defp changeset_error_summary(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, _opts} -> message end)
    |> flatten_error_messages()
    |> Enum.join(", ")
    |> case do
      "" -> "Please check the highlighted visit fields."
      message -> message
    end
  end

  defp flatten_error_messages(errors) when is_map(errors) do
    Enum.flat_map(errors, fn
      {field, messages} when is_list(messages) ->
        Enum.map(messages, &"#{Phoenix.Naming.humanize(field)} #{&1}")

      {_field, nested_errors} ->
        flatten_error_messages(nested_errors)
    end)
  end

  defp flatten_error_messages(errors) when is_list(errors) do
    Enum.flat_map(errors, &flatten_error_messages/1)
  end

  defp flatten_error_messages(_errors), do: []

  defp tank_level_options,
    do: Enum.map(FarmVisitReport.tank_level_options(), &{tank_level_label(&1), &1})

  defp overall_status_options,
    do: Enum.map(FarmVisitReport.overall_status_options(), &{overall_status_label(&1), &1})

  defp plant_health_options,
    do: Enum.map(FarmVisitGreenhouseStatus.plant_health_options(), &{choice_label(&1), &1})

  defp weeding_status_options,
    do: Enum.map(FarmVisitGreenhouseStatus.weeding_status_options(), &{choice_label(&1), &1})

  defp modal_eyebrow(nil), do: "New Visit"
  defp modal_eyebrow(_report), do: "Edit Visit"

  defp modal_title(nil), do: "Capture farm visit"
  defp modal_title(report), do: "Edit #{format_date(report.visited_on)} visit"

  defp submit_label(nil), do: "Save visit report"
  defp submit_label(_report), do: "Save changes"

  defp latest_visitor(nil), do: "No visits saved yet"
  defp latest_visitor(report), do: "Visited by #{report.visited_by}"

  defp signed_by(%{sign_off: sign_off}) when sign_off not in [nil, ""],
    do: "Signed by #{sign_off}"

  defp signed_by(_report), do: "Not signed off"

  defp issue_count(nil), do: 0

  defp issue_count(report) do
    water_issue = if report.water_reserve_compliant, do: 0, else: 1

    greenhouse_issues =
      Enum.count(report.greenhouse_statuses, fn status ->
        status.plant_health == "bad" or status.weeding_status == "poor" or
          status.foot_bath_compliant == false
      end)

    water_issue + greenhouse_issues
  end

  defp tank_level_label("below_half"), do: "Below half"
  defp tank_level_label("half"), do: "Half"
  defp tank_level_label("above_half"), do: "Above half"
  defp tank_level_label(value), do: choice_label(value)

  defp overall_status_label("on_track"), do: "On track"
  defp overall_status_label("needs_attention"), do: "Needs attention"
  defp overall_status_label("critical"), do: "Critical"
  defp overall_status_label(value), do: choice_label(value)

  defp choice_label(nil), do: "-"
  defp choice_label(""), do: "-"

  defp choice_label(value) do
    value
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp compliance_label(true), do: "Compliant"
  defp compliance_label(false), do: "Non-compliant"
  defp compliance_label(_value), do: "-"

  defp compliance_class(true),
    do: "mt-1 text-xs font-semibold uppercase tracking-[0.18em] text-[var(--brand-green-deep)]"

  defp compliance_class(false),
    do: "mt-1 text-xs font-semibold uppercase tracking-[0.18em] text-rose-700"

  defp compliance_pill_class(true),
    do:
      "rounded-full bg-white px-3 py-1 text-xs font-semibold uppercase tracking-[0.16em] text-[var(--brand-green-deep)]"

  defp compliance_pill_class(false),
    do:
      "rounded-full bg-white px-3 py-1 text-xs font-semibold uppercase tracking-[0.16em] text-rose-700"

  defp overall_status_class("on_track"),
    do:
      "inline-flex rounded-full bg-[var(--surface-soft)] px-3 py-1 text-xs font-semibold uppercase tracking-[0.16em] text-[var(--brand-green-deep)]"

  defp overall_status_class("needs_attention"),
    do:
      "inline-flex rounded-full bg-amber-50 px-3 py-1 text-xs font-semibold uppercase tracking-[0.16em] text-amber-800"

  defp overall_status_class("critical"),
    do:
      "inline-flex rounded-full bg-rose-50 px-3 py-1 text-xs font-semibold uppercase tracking-[0.16em] text-rose-800"

  defp overall_status_class(_status),
    do:
      "inline-flex rounded-full bg-zinc-50 px-3 py-1 text-xs font-semibold uppercase tracking-[0.16em] text-zinc-700"

  defp blank_fallback(nil), do: "-"
  defp blank_fallback(""), do: "-"
  defp blank_fallback(value), do: value

  defp format_size(nil), do: "size unset"
  defp format_size(""), do: "size unset"
  defp format_size("8x40"), do: "8 x 40"
  defp format_size("16x40"), do: "16 x 40"
  defp format_size(size), do: size

  defp format_date(nil), do: "-"
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")

  defp iso_date(nil), do: ""
  defp iso_date(%Date{} = date), do: Date.to_iso8601(date)
end
