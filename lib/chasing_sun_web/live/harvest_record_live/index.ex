defmodule ChasingSunWeb.HarvestRecordLive.Index do
  use ChasingSunWeb, :live_view

  alias ChasingSun.Harvesting
  alias ChasingSun.Harvesting.HarvestRecord
  alias ChasingSun.OpenAI
  alias ChasingSun.Operations

  @impl true
  def mount(params, _session, socket) do
    venture_code = params["venture_code"] || "all"

    {:ok,
     socket
     |> allow_upload(:pickup_note,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 8_000_000
     )
     |> assign(:page_title, "Harvest Records")
     |> assign(:current_harvest_record, nil)
     |> assign(:pickup_note_analysis, nil)
     |> assign(:form_modal_open, false)
     |> load_records(venture_code)
     |> reset_form()}
  end

  @impl true
  def handle_event("filter", %{"venture_code" => venture_code}, socket) do
    {:noreply, socket |> load_records(venture_code) |> reset_form()}
  end

  def handle_event("open_form_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:current_harvest_record, nil)
     |> clear_pickup_note_context()
     |> reset_form()
     |> assign(:form_modal_open, true)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    record = find_record!(socket.assigns.records, id)

    {:noreply,
     socket
     |> assign(:current_harvest_record, record)
     |> clear_pickup_note_context()
     |> assign(:form_modal_open, true)
     |> assign(:harvest_form, harvest_form_for(record))}
  end

  def handle_event("close_form_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:current_harvest_record, nil)
     |> assign(:form_modal_open, false)
     |> reset_form()}
  end

  def handle_event("validate_pickup_note", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel_pickup_note_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :pickup_note, ref)}
  end

  def handle_event("analyze_pickup_note", _params, socket) do
    if ChasingSunWeb.UserAuth.can?(socket.assigns.current_user, :manage_harvest) do
      analyze_pickup_note(socket)
    else
      {:noreply, put_flash(socket, :error, "You do not have permission to record harvests.")}
    end
  end

  def handle_event("save", %{"harvest" => harvest_params}, socket) do
    if ChasingSunWeb.UserAuth.can?(socket.assigns.current_user, :manage_harvest) do
      result =
        case socket.assigns.current_harvest_record do
          nil ->
            Harvesting.upsert_harvest_record(harvest_params, socket.assigns.current_user)

          record ->
            Harvesting.update_harvest_record(
              record,
              normalize_harvest_attrs(harvest_params, socket.assigns.current_user),
              socket.assigns.current_user
            )
        end

      case result do
        {:ok, _record} ->
          message =
            if socket.assigns.current_harvest_record,
              do: "Harvest record updated.",
              else: "Harvest record saved."

          {:noreply,
           socket
           |> put_flash(:info, message)
           |> assign(:current_harvest_record, nil)
           |> load_records(socket.assigns.selected_venture)
           |> reset_form()}

        {:error, %Ecto.Changeset{data: %HarvestRecord{}} = changeset} ->
          {:noreply,
           socket
           |> assign(:form_modal_open, true)
           |> assign(:harvest_form, to_form(Map.put(changeset, :action, :validate), as: :harvest))
           |> put_flash(:error, changeset_error_summary(changeset))}
      end
    else
      {:noreply, put_flash(socket, :error, "You do not have permission to record harvests.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-6">
      <div class="grid gap-6 xl:grid-cols-[minmax(0,1.6fr)_minmax(320px,1fr)]">
        <div class="panel-shell">
          <p class="eyebrow">Harvest Capture</p>
          <h1 class="page-title">Weekly yield records</h1>
          <p class="page-copy">
            Record actual harvest by greenhouse and week. Existing records for the same greenhouse and week are updated in place.
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
              title="Record count"
              value={length(@records)}
              hint="Rows in this filtered view"
            />
            <.summary_card
              title="Total yield"
              value={format_quantity(Enum.reduce(@records, 0.0, &(&1.actual_yield + &2)))}
              hint="Summed across visible rows"
              accent="yellow"
            />
            <.summary_card
              title="Tracked greenhouses"
              value={@tracked_units}
              hint="Units with at least one harvest entry"
              accent="ink"
            />
          </div>
        </div>

        <div class="panel-shell">
          <p class="eyebrow">Quick Actions</p>
          <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
            Log harvests in a popup
          </h2>
          <p class="mt-4 text-sm leading-6 text-[var(--muted)]">
            Keep the performance history visible while entering weekly actuals in a focused modal, or prefill the form from a pickup note image.
          </p>

          <div class="mt-6 space-y-4">
            <button
              :if={ChasingSunWeb.UserAuth.can?(@current_user, :manage_harvest)}
              type="button"
              phx-click="open_form_modal"
              class="inline-flex w-full items-center justify-center rounded-[1.25rem] bg-[var(--brand-green)] px-4 py-3 text-sm font-semibold text-white transition hover:bg-[var(--brand-green-deep)]"
            >
              New harvest record
            </button>
            <p class="rounded-[1.5rem] border border-[var(--line)] bg-[var(--surface-soft)] px-4 py-4 text-sm text-[var(--muted)]">
              The active crop cycle is auto-linked when available.
            </p>
          </div>
        </div>
      </div>

      <div class="panel-shell">
        <p class="eyebrow">Recent Records</p>
        <h2 class="mt-3 text-2xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
          Harvest history
        </h2>

        <div class="mt-6 overflow-x-auto">
          <table class="data-table">
            <thead>
              <tr>
                <th>Week</th>
                <th>Greenhouse</th>
                <th>Venture</th>
                <th>Crop</th>
                <th>Actual yield</th>
                <th>Notes</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={record <- @records}>
                <td>{format_date(record.week_ending_on)}</td>
                <td>
                  <p class="font-semibold text-[var(--ink)]">{record.greenhouse.name}</p>
                  <p class="mt-1 text-xs text-[var(--muted)]">Unit {record.greenhouse.sequence_no}</p>
                </td>
                <td>{record.greenhouse.venture.name}</td>
                <td>{(record.crop_cycle && record.crop_cycle.crop_type) || "No cycle"}</td>
                <td class="font-semibold text-[var(--ink)]">
                  {format_quantity(record.actual_yield)}
                </td>
                <td class="max-w-xs text-[var(--muted)]">{blank_fallback(record.notes)}</td>
                <td class="text-right">
                  <button
                    :if={ChasingSunWeb.UserAuth.can?(@current_user, :manage_harvest)}
                    type="button"
                    phx-click="edit"
                    phx-value-id={record.id}
                    class="action-link"
                  >
                    Edit
                  </button>
                </td>
              </tr>
              <tr :if={Enum.empty?(@records)}>
                <td colspan="7" class="text-center text-sm text-[var(--muted)]">
                  No harvest records found.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <.modal
        :if={@form_modal_open}
        id="harvest-form-modal"
        show
        on_cancel={JS.push("close_form_modal")}
      >
        <div class="space-y-6">
          <div>
            <p class="eyebrow">{modal_eyebrow(@current_harvest_record)}</p>
            <h2 class="mt-3 text-3xl font-semibold tracking-[-0.05em] text-[var(--ink)]">
              {modal_title(@current_harvest_record)}
            </h2>
          </div>

          <%!-- <div class="rounded-[1.5rem] border border-[var(--line)] bg-[var(--surface-soft)] p-5">
            <p class="text-sm font-semibold text-[var(--ink)]">Pickup note image</p>
            <p class="mt-2 text-sm leading-6 text-[var(--muted)]">
              Upload a pickup note and let AI detect the greenhouse, harvest quantity, and any visible note details before you save the record.
            </p>

            <.form
              for={%{}}
              as={:pickup_note}
              phx-change="validate_pickup_note"
              phx-submit="analyze_pickup_note"
              class="mt-4 space-y-4"
            >
              <label class="block rounded-[1.25rem] border border-dashed border-[var(--line)] bg-white px-4 py-4 text-sm text-[var(--muted)]">
                <span class="font-semibold text-[var(--ink)]">Choose pickup note image</span>
                <.live_file_input
                  upload={@uploads.pickup_note}
                  class="mt-3 block w-full text-sm text-[var(--muted)]"
                />
              </label>

              <div
                :for={entry <- @uploads.pickup_note.entries}
                class="rounded-[1rem] bg-white px-4 py-3"
              >
                <div class="flex items-center justify-between gap-4">
                  <div>
                    <p class="text-sm font-semibold text-[var(--ink)]">{entry.client_name}</p>
                    <p class="mt-1 text-xs uppercase tracking-[0.18em] text-[var(--muted)]">
                      {entry.progress}% uploaded
                    </p>
                  </div>
                  <button
                    type="button"
                    phx-click="cancel_pickup_note_upload"
                    phx-value-ref={entry.ref}
                    class="text-sm font-semibold text-[var(--brand-green-deep)]"
                  >
                    Remove
                  </button>
                </div>

                <p
                  :for={error <- upload_errors(@uploads.pickup_note, entry)}
                  class="mt-2 text-sm text-rose-600"
                >
                  {upload_error_text(error)}
                </p>
              </div>

              <p :for={error <- upload_errors(@uploads.pickup_note)} class="text-sm text-rose-600">
                {upload_error_text(error)}
              </p>

              <button
                type="submit"
                class="inline-flex items-center justify-center rounded-[1.25rem] bg-[var(--ink)] px-4 py-3 text-sm font-semibold text-white transition hover:bg-[var(--brand-green-deep)]"
              >
                Analyze pickup note
              </button>
            </.form>

            <div :if={@pickup_note_analysis} class="mt-4 rounded-[1.25rem] bg-white px-4 py-4">
              <p class="text-sm font-semibold text-[var(--ink)]">
                {pickup_note_heading(@pickup_note_analysis)}
              </p>
              <p class="mt-2 text-sm text-[var(--muted)]">
                {pickup_note_summary(@pickup_note_analysis)}
              </p>
              <p class="mt-3 text-xs uppercase tracking-[0.18em] text-[var(--muted)]">
                Confidence {pickup_note_confidence(@pickup_note_analysis)}
              </p>
            </div>
          </div> --%>

          <.form for={@harvest_form} phx-submit="save" class="space-y-5">
            <.input
              field={@harvest_form[:greenhouse_id]}
              type="select"
              label="Greenhouse"
              options={greenhouse_options(@form_greenhouses)}
              required
            />
            <.input
              field={@harvest_form[:week_ending_on]}
              type="date"
              label="Week ending on"
              required
            />
            <.input
              field={@harvest_form[:actual_yield]}
              type="number"
              step="0.1"
              label="Actual yield"
              required
            />
            <.input
              field={@harvest_form[:notes]}
              type="textarea"
              label="Notes"
              rows="4"
              placeholder="Harvest notes, quality flags, losses, or labour notes"
            />

            <div class="flex items-center justify-between gap-4">
              <button type="button" phx-click="close_form_modal" class="nav-chip">Cancel</button>
              <.button>{submit_label(@current_harvest_record)}</.button>
            </div>
          </.form>
        </div>
      </.modal>
    </section>
    """
  end

  defp load_records(socket, venture_code) do
    records = Harvesting.list_harvest_records(filters_for(venture_code))

    assign(socket,
      selected_venture: venture_code,
      ventures: Operations.list_ventures(),
      records: records,
      tracked_units: records |> Enum.map(& &1.greenhouse_id) |> Enum.uniq() |> length(),
      form_greenhouses: Operations.list_greenhouses(filters_for(venture_code))
    )
  end

  defp reset_form(socket) do
    default_greenhouse_id =
      socket.assigns.form_greenhouses |> List.first() |> then(&((&1 && &1.id) || ""))

    socket
    |> clear_pickup_note_uploads()
    |> assign(:pickup_note_analysis, nil)
    |> assign(
      form_modal_open: false,
      harvest_form:
        to_form(
          %{
            "greenhouse_id" => default_greenhouse_id,
            "week_ending_on" =>
              Date.utc_today()
              |> ChasingSun.Operations.CropPlanner.next_saturday()
              |> Date.to_iso8601(),
            "actual_yield" => "",
            "notes" => ""
          },
          as: :harvest
        )
    )
  end

  defp harvest_form_for(record) do
    to_form(
      %{
        "greenhouse_id" => record.greenhouse_id,
        "week_ending_on" => Date.to_iso8601(record.week_ending_on),
        "actual_yield" => record.actual_yield,
        "notes" => record.notes || ""
      },
      as: :harvest
    )
  end

  defp greenhouse_options(greenhouses),
    do: Enum.map(greenhouses, &{"#{&1.name} (#{&1.venture.code})", &1.id})

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

  defp normalize_harvest_attrs(attrs, actor) do
    greenhouse = Operations.get_greenhouse!(attrs["greenhouse_id"] || attrs[:greenhouse_id])
    crop_cycle = Operations.current_cycle(greenhouse)

    attrs
    |> Map.new(fn {key, value} -> {to_string(key), value} end)
    |> Map.put("crop_cycle_id", crop_cycle && crop_cycle.id)
    |> Map.put("inserted_by_user_id", actor && actor.id)
  end

  defp find_record!(records, id) do
    Enum.find(records, &(to_string(&1.id) == id)) ||
      raise Ecto.NoResultsError, queryable: HarvestRecord
  end

  defp modal_eyebrow(nil), do: "New Record"
  defp modal_eyebrow(_record), do: "Edit Record"

  defp modal_title(nil), do: "Capture weekly actuals"
  defp modal_title(record), do: "Edit #{record.greenhouse.name} harvest"

  defp submit_label(nil), do: "Create harvest record"
  defp submit_label(_record), do: "Save changes"

  defp format_quantity(value), do: format_number(value, decimals: 1)

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")
  defp format_date(_date), do: "-"

  defp blank_fallback(nil), do: "-"
  defp blank_fallback(""), do: "-"
  defp blank_fallback(value), do: value

  defp analyze_pickup_note(socket) do
    case uploaded_entries(socket, :pickup_note) do
      {[], []} ->
        {:noreply, put_flash(socket, :error, "Upload a pickup note image first.")}

      {_completed, [_ | _]} ->
        {:noreply, put_flash(socket, :error, "Please wait for the image upload to finish.")}

      {_completed, []} ->
        images =
          consume_uploaded_entries(socket, :pickup_note, fn %{path: path}, entry ->
            {:ok,
             %{
               binary: File.read!(path),
               mime_type: entry.client_type,
               filename: entry.client_name
             }}
          end)

        case images do
          [image] ->
            apply_pickup_note_analysis(socket, image)

          _ ->
            {:noreply,
             put_flash(socket, :error, "Only one pickup note image can be analyzed at a time.")}
        end
    end
  end

  defp apply_pickup_note_analysis(socket, image) do
    case OpenAI.extract_harvest_from_pickup_note(image, socket.assigns.form_greenhouses) do
      {:ok, extracted} ->
        flash_kind =
          if harvest_payload_ready?(extracted), do: :info, else: :error

        flash_message =
          if harvest_payload_ready?(extracted) do
            "Pickup note analyzed. Please confirm the pre-filled harvest record."
          else
            "The image was read, but the greenhouse or harvest quantity could not be matched confidently."
          end

        {:noreply,
         socket
         |> assign(:pickup_note_analysis, extracted)
         |> assign(
           :harvest_form,
           to_form(merge_harvest_form(socket.assigns.harvest_form, extracted), as: :harvest)
         )
         |> put_flash(flash_kind, flash_message)}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  defp merge_harvest_form(form, extracted) do
    form
    |> harvest_form_values()
    |> maybe_put_value("greenhouse_id", extracted["greenhouse_id"])
    |> maybe_put_value("week_ending_on", extracted["week_ending_on"])
    |> maybe_put_value("actual_yield", extracted["actual_yield"])
    |> merge_notes(extracted["notes"])
  end

  defp harvest_form_values(form) do
    %{
      "greenhouse_id" => form[:greenhouse_id].value || "",
      "week_ending_on" => form[:week_ending_on].value || "",
      "actual_yield" => form[:actual_yield].value || "",
      "notes" => form[:notes].value || ""
    }
  end

  defp maybe_put_value(params, _key, ""), do: params
  defp maybe_put_value(params, _key, nil), do: params
  defp maybe_put_value(params, key, value), do: Map.put(params, key, value)

  defp merge_notes(params, ""), do: params

  defp merge_notes(params, note) do
    merged_note =
      [params["notes"], note]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.uniq()
      |> Enum.join("\n\n")

    Map.put(params, "notes", merged_note)
  end

  defp harvest_payload_ready?(extracted) do
    extracted["found_harvest_data"] == true and extracted["greenhouse_id"] != "" and
      extracted["actual_yield"] not in ["", nil]
  end

  defp pickup_note_heading(extracted) do
    case extracted["greenhouse_name"] do
      "" -> "Pickup note parsed"
      greenhouse_name -> "Pickup note matched to #{greenhouse_name}"
    end
  end

  defp pickup_note_summary(extracted) do
    extracted["notes"]
    |> blank_fallback()
  end

  defp pickup_note_confidence(extracted) do
    extracted["confidence"]
    |> Kernel.*(100)
    |> Float.round(0)
    |> trunc()
    |> Integer.to_string()
    |> Kernel.<>("%")
  end

  defp clear_pickup_note_uploads(socket) do
    Enum.reduce(socket.assigns.uploads.pickup_note.entries, socket, fn entry, acc ->
      cancel_upload(acc, :pickup_note, entry.ref)
    end)
  end

  defp clear_pickup_note_context(socket) do
    socket
    |> clear_pickup_note_uploads()
    |> assign(:pickup_note_analysis, nil)
  end

  defp upload_error_text(:too_large), do: "This file is too large."
  defp upload_error_text(:not_accepted), do: "Use a JPG, PNG, or WEBP image."
  defp upload_error_text(:too_many_files), do: "Upload only one pickup note image."
  defp upload_error_text(error), do: "Upload failed: #{inspect(error)}"
end
