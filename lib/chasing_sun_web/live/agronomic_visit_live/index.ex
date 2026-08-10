defmodule ChasingSunWeb.AgronomicVisitLive.Index do
  @moduledoc """
  Bi-weekly agronomic visits: log a visit with its PDF/Word report and see how
  the schedule is tracking. Lateness alerts are raised by
  `ChasingSun.Operations.check_agronomic_visit_schedule/1`, which also runs on
  mount so the board is current even between daily refreshes.
  """

  use ChasingSunWeb, :live_view

  alias ChasingSun.Operations
  alias ChasingSun.Operations.AgronomicVisit

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(ChasingSun.PubSub, Operations.operations_topic())
    end

    Operations.check_agronomic_visit_schedule()

    {:ok,
     socket
     |> allow_upload(:report,
       accept: Operations.agronomic_report_extensions(),
       max_entries: 1,
       max_file_size: Operations.agronomic_report_max_size()
     )
     |> assign(:page_title, "Agronomic Visits")
     |> assign(:form_modal_open, false)
     |> load_visits()
     |> reset_form()}
  end

  @impl true
  def handle_info({:operation_notification, _notification}, socket) do
    {:noreply, load_visits(socket)}
  end

  def handle_info({:operations_refreshed, _today}, socket) do
    {:noreply, load_visits(socket)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def handle_event("open_form_modal", _params, socket) do
    {:noreply, socket |> reset_form() |> assign(:form_modal_open, true)}
  end

  def handle_event("close_form_modal", _params, socket) do
    {:noreply, socket |> assign(:form_modal_open, false) |> clear_upload_entries()}
  end

  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :report, ref)}
  end

  def handle_event("save", %{"agronomic_visit" => params}, socket) do
    if can_manage?(socket) do
      case uploaded_entries(socket, :report) do
        {[], []} ->
          {:noreply,
           put_flash(socket, :error, "Attach the agronomic report (PDF or Word) first.")}

        {_completed, [_ | _]} ->
          {:noreply, put_flash(socket, :error, "Please wait for the upload to finish.")}

        {_completed, []} ->
          save_visit(socket, params)
      end
    else
      {:noreply, put_flash(socket, :error, "You do not have permission to log agronomic visits.")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    if can_manage?(socket) do
      visit = Operations.get_agronomic_visit!(id)
      {:ok, _visit} = Operations.delete_agronomic_visit(visit, socket.assigns.current_user)

      {:noreply, socket |> put_flash(:info, "Agronomic visit deleted.") |> load_visits()}
    else
      {:noreply,
       put_flash(socket, :error, "You do not have permission to delete agronomic visits.")}
    end
  end

  defp save_visit(socket, params) do
    [file_attrs] =
      consume_uploaded_entries(socket, :report, fn %{path: path}, entry ->
        filename = unique_filename(entry.client_name)
        dest = Path.join(Operations.agronomic_report_upload_root(), filename)
        File.mkdir_p!(Path.dirname(dest))
        File.cp!(path, dest)

        {:ok,
         %{
           "report_file_url" => filename,
           "report_file_name" => entry.client_name,
           "content_type" => entry.client_type,
           "byte_size" => File.stat!(dest).size
         }}
      end)

    attrs = Map.merge(params, file_attrs)

    case Operations.create_agronomic_visit(attrs, socket.assigns.current_user) do
      {:ok, _visit} ->
        {:noreply,
         socket
         |> put_flash(:info, "Agronomic visit logged.")
         |> assign(:form_modal_open, false)
         |> load_visits()
         |> reset_form()}

      {:error, changeset} ->
        # The stored file is orphaned if validation fails, so clean it up.
        Operations.agronomic_report_upload_root()
        |> Path.join(file_attrs["report_file_url"])
        |> File.rm()

        {:noreply,
         assign(socket, :form, to_form(changeset, action: :validate, as: :agronomic_visit))}
    end
  end

  defp load_visits(socket) do
    assign(socket,
      visits: Operations.list_agronomic_visits(),
      schedule: Operations.agronomic_visit_schedule()
    )
  end

  defp reset_form(socket) do
    assign(
      socket,
      :form,
      to_form(
        Operations.change_agronomic_visit(%AgronomicVisit{}, %{
          "visited_on" => Date.utc_today()
        }),
        as: :agronomic_visit
      )
    )
  end

  defp clear_upload_entries(socket) do
    Enum.reduce(socket.assigns.uploads.report.entries, socket, fn entry, acc ->
      cancel_upload(acc, :report, entry.ref)
    end)
  end

  defp can_manage?(socket) do
    ChasingSunWeb.UserAuth.can?(socket.assigns.current_user, :manage_agronomic_visits)
  end

  defp unique_filename(client_name) do
    ext = Path.extname(client_name)
    base = client_name |> Path.basename(ext) |> String.replace(~r/[^a-zA-Z0-9_-]+/, "-")
    "#{System.unique_integer([:positive, :monotonic])}-#{base}#{ext}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-8">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 class="page-title">Agronomic visits</h1>
          <p class="mt-1 text-sm text-[var(--muted)]">
            Expected every {@schedule.interval_days} days. Each visit carries its agronomic report
            as a PDF or Word document.
          </p>
        </div>
        <button
          type="button"
          phx-click="open_form_modal"
          class="bg-green-700 hover:bg-green-800 text-white text-sm font-medium px-4 py-2 rounded-lg"
        >
          Log agronomic visit
        </button>
      </div>

      <div class={schedule_banner_class(@schedule.state)}>
        <p class="text-xs uppercase tracking-[0.18em]">{schedule_label(@schedule.state)}</p>
        <p class="mt-2 text-sm">{schedule_message(@schedule)}</p>
      </div>

      <div class="panel-shell">
        <div class="overflow-x-auto">
          <table class="data-table">
            <thead>
              <tr>
                <th>Visited on</th>
                <th>Agronomist</th>
                <th>Summary</th>
                <th>Report</th>
                <th>Logged by</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={visit <- @visits}>
                <td>{format_visit_date(visit.visited_on)}</td>
                <td>{visit.agronomist_name}</td>
                <td class="max-w-md text-sm text-[var(--muted)]">{visit.summary || "-"}</td>
                <td>
                  <a href={~p"/agronomic-visits/#{visit.id}/report"} class="action-link">
                    {visit.report_file_name || "Download"}
                  </a>
                </td>
                <td>{(visit.inserted_by_user && visit.inserted_by_user.email) || "-"}</td>
                <td class="text-right">
                  <button
                    type="button"
                    phx-click="delete"
                    phx-value-id={visit.id}
                    data-confirm="Delete this agronomic visit and its report?"
                    class="action-link"
                  >
                    Delete
                  </button>
                </td>
              </tr>
              <tr :if={Enum.empty?(@visits)}>
                <td colspan="6" class="text-center text-sm text-zinc-400">
                  No agronomic visits recorded yet.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <.modal
        :if={@form_modal_open}
        id="agronomic-visit-modal"
        show
        on_cancel={JS.push("close_form_modal")}
      >
        <div class="space-y-6">
          <h2 class="section-heading">Log agronomic visit</h2>

          <form phx-change="validate" phx-submit="save" class="space-y-5">
            <label class="block rounded-lg border border-dashed border-zinc-300 bg-white px-4 py-4 text-sm text-zinc-500">
              <span class="font-semibold text-zinc-900">Agronomic report (PDF or Word)</span>
              <.live_file_input upload={@uploads.report} class="mt-3 block w-full text-sm text-zinc-500" />
            </label>

            <div :for={entry <- @uploads.report.entries} class="rounded-lg bg-zinc-50 px-4 py-3">
              <div class="flex items-center justify-between gap-4">
                <p class="text-sm font-medium text-zinc-900">{entry.client_name}</p>
                <button
                  type="button"
                  phx-click="cancel_upload"
                  phx-value-ref={entry.ref}
                  class="action-link"
                >
                  Remove
                </button>
              </div>
              <p
                :for={error <- upload_errors(@uploads.report, entry)}
                class="mt-2 text-sm text-rose-600"
              >
                {upload_error_text(error)}
              </p>
            </div>

            <p :for={error <- upload_errors(@uploads.report)} class="text-sm text-rose-600">
              {upload_error_text(error)}
            </p>

            <.input field={@form[:visited_on]} type="date" label="Visited on" required />
            <.input field={@form[:agronomist_name]} type="text" label="Agronomist" required />
            <.input field={@form[:summary]} type="textarea" label="Summary / key findings" />

            <div class="flex items-center justify-between gap-4">
              <button type="button" phx-click="close_form_modal" class="nav-chip">Cancel</button>
              <.button class="bg-green-700 hover:bg-green-800">Save visit</.button>
            </div>
          </form>
        </div>
      </.modal>
    </section>
    """
  end

  defp schedule_label(:late), do: "Overdue"
  defp schedule_label(:no_visits), do: "Not started"
  defp schedule_label(:due_today), do: "Due today"
  defp schedule_label(:on_track), do: "On track"

  defp schedule_message(%{state: :no_visits, interval_days: interval}) do
    "No agronomic visit recorded yet. Log the latest report to start the #{interval}-day schedule."
  end

  defp schedule_message(%{state: :late} = schedule) do
    "Overdue by #{schedule.days_overdue} #{if schedule.days_overdue == 1, do: "day", else: "days"}. " <>
      "Last visit #{format_visit_date(schedule.last_visit.visited_on)}, due #{format_visit_date(schedule.due_on)}."
  end

  defp schedule_message(%{state: :due_today} = schedule) do
    "The next agronomic visit is due today. Last visit was #{format_visit_date(schedule.last_visit.visited_on)}."
  end

  defp schedule_message(%{state: :on_track} = schedule) do
    "Next visit due #{format_visit_date(schedule.due_on)}. Last visit was #{format_visit_date(schedule.last_visit.visited_on)}."
  end

  defp schedule_banner_class(state) do
    base = "rounded-[1.5rem] border p-5"

    case state do
      state when state in [:late, :no_visits] ->
        "#{base} border-rose-200 bg-rose-50 text-rose-700"

      :due_today ->
        "#{base} border-amber-200 bg-amber-50 text-amber-700"

      :on_track ->
        "#{base} border-[var(--line)] bg-[var(--surface-soft)] text-[var(--muted)]"
    end
  end

  defp format_visit_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")
  defp format_visit_date(_date), do: "-"

  defp upload_error_text(:too_large), do: "This file is too large (max 20MB)."
  defp upload_error_text(:not_accepted), do: "Upload a PDF or Word document."
  defp upload_error_text(:too_many_files), do: "Upload only one report at a time."
  defp upload_error_text(error), do: "Upload failed: #{inspect(error)}"
end
