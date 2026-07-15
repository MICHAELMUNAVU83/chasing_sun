defmodule ChasingSunWeb.DocumentsLive.Index do
  use ChasingSunWeb, :live_view

  alias ChasingSun.Documents
  alias ChasingSun.Documents.Document

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> allow_upload(:document,
       accept: Documents.allowed_extensions(),
       max_entries: 1,
       max_file_size: Documents.max_upload_size()
     )
     |> assign(:page_title, "Documents")
     |> assign(:selected_department, nil)
     |> assign(:search_query, "")
     |> assign(:upload_modal_open, false)
     |> load_documents()
     |> reset_upload_form()}
  end

  @impl true
  def handle_event("select_department", %{"department" => department}, socket) do
    selected = if department == "", do: nil, else: department
    {:noreply, socket |> assign(:selected_department, selected) |> load_documents()}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, socket |> assign(:search_query, query) |> load_documents()}
  end

  def handle_event("open_upload_modal", _params, socket) do
    {:noreply, socket |> reset_upload_form() |> assign(:upload_modal_open, true)}
  end

  def handle_event("close_upload_modal", _params, socket) do
    {:noreply, socket |> assign(:upload_modal_open, false) |> clear_upload_entries()}
  end

  def handle_event("validate_upload", _params, socket), do: {:noreply, socket}

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :document, ref)}
  end

  def handle_event("save_document", %{"document" => params}, socket) do
    case uploaded_entries(socket, :document) do
      {[], []} ->
        {:noreply, put_flash(socket, :error, "Choose a file to upload first.")}

      {_completed, [_ | _]} ->
        {:noreply, put_flash(socket, :error, "Please wait for the upload to finish.")}

      {_completed, []} ->
        [file_attrs] =
          consume_uploaded_entries(socket, :document, fn %{path: path}, entry ->
            filename = unique_filename(entry.client_name)
            dest = Path.join(Documents.upload_root(), filename)
            File.cp!(path, dest)

            {:ok,
             %{
               "file_url" => filename,
               "content_type" => entry.client_type,
               "byte_size" => File.stat!(dest).size
             }}
          end)

        attrs = Map.merge(params, file_attrs)

        case Documents.create_document(attrs, socket.assigns.current_user) do
          {:ok, _document} ->
            {:noreply,
             socket
             |> put_flash(:info, "Document uploaded.")
             |> assign(:upload_modal_open, false)
             |> load_documents()
             |> reset_upload_form()}

          {:error, changeset} ->
            {:noreply, assign(socket, :upload_form, to_form(changeset, action: :validate, as: :document))}
        end
    end
  end

  defp load_documents(socket) do
    user = socket.assigns.current_user
    base_filters = %{"query" => socket.assigns.search_query}

    all_visible = Documents.list_documents(user, base_filters)
    department_counts = Enum.frequencies_by(all_visible, &to_string(&1.department))

    documents =
      if socket.assigns.selected_department do
        Documents.list_documents(
          user,
          Map.put(base_filters, "department", socket.assigns.selected_department)
        )
      else
        all_visible
      end

    assign(socket, documents: documents, department_counts: department_counts)
  end

  defp reset_upload_form(socket) do
    assign(socket, :upload_form, to_form(Documents.change_document(%Document{}), as: :document))
  end

  defp clear_upload_entries(socket) do
    Enum.reduce(socket.assigns.uploads.document.entries, socket, fn entry, acc ->
      cancel_upload(acc, :document, entry.ref)
    end)
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
      <div class="flex items-center justify-between gap-4">
        <h1 class="page-title">Documents</h1>
        <button
          type="button"
          phx-click="open_upload_modal"
          class="bg-green-700 hover:bg-green-800 text-white text-sm font-medium px-4 py-2 rounded-lg"
        >
          Upload document
        </button>
      </div>

      <div class="flex flex-wrap items-center justify-between gap-4">
        <div class="flex flex-wrap gap-2">
          <button
            type="button"
            phx-click="select_department"
            phx-value-department=""
            class={filter_tab_class(@selected_department, nil)}
          >
            All ({total_count(@department_counts)})
          </button>
          <button
            :for={department <- enum_values(Document, :department)}
            type="button"
            phx-click="select_department"
            phx-value-department={department}
            class={filter_tab_class(@selected_department, to_string(department))}
          >
            {Phoenix.Naming.humanize(department)} ({Map.get(@department_counts, to_string(department), 0)})
          </button>
        </div>

        <form phx-change="search" class="flex items-center gap-2">
          <input
            type="text"
            name="query"
            value={@search_query}
            placeholder="Search by title or tag"
            class="rounded-lg border border-zinc-300 text-sm"
          />
        </form>
      </div>

      <div class="panel-shell">
        <div class="overflow-x-auto">
          <table class="data-table">
            <thead>
              <tr>
                <th>Title</th>
                <th>Department</th>
                <th>Tags</th>
                <th>Uploaded by</th>
                <th>Uploaded on</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={document <- @documents}>
                <td>{document.title}</td>
                <td>{Phoenix.Naming.humanize(document.department)}</td>
                <td>
                  <span :for={tag <- document.tags} class="mr-1 inline-flex items-center rounded-full border border-zinc-200 bg-zinc-50 px-2 py-0.5 text-xs text-zinc-600">
                    {tag}
                  </span>
                </td>
                <td>{document.uploaded_by && document.uploaded_by.email || "-"}</td>
                <td>{format_date(document.inserted_at)}</td>
                <td class="text-right">
                  <a href={~p"/documents/#{document.id}/download"} class="action-link">Download</a>
                </td>
              </tr>
              <tr :if={Enum.empty?(@documents)}>
                <td colspan="6" class="text-center text-sm text-zinc-400">No documents found.</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <.modal :if={@upload_modal_open} id="upload-document-modal" show on_cancel={JS.push("close_upload_modal")}>
        <div class="space-y-6">
          <h2 class="section-heading">Upload document</h2>

          <form phx-change="validate_upload" phx-submit="save_document" class="space-y-5">
            <label class="block rounded-lg border border-dashed border-zinc-300 bg-white px-4 py-4 text-sm text-zinc-500">
              <span class="font-semibold text-zinc-900">Choose a file</span>
              <.live_file_input upload={@uploads.document} class="mt-3 block w-full text-sm text-zinc-500" />
            </label>

            <div :for={entry <- @uploads.document.entries} class="rounded-lg bg-zinc-50 px-4 py-3">
              <div class="flex items-center justify-between gap-4">
                <p class="text-sm font-medium text-zinc-900">{entry.client_name}</p>
                <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} class="action-link">
                  Remove
                </button>
              </div>
              <p :for={error <- upload_errors(@uploads.document, entry)} class="mt-2 text-sm text-rose-600">
                {upload_error_text(error)}
              </p>
            </div>

            <p :for={error <- upload_errors(@uploads.document)} class="text-sm text-rose-600">
              {upload_error_text(error)}
            </p>

            <.input field={@upload_form[:title]} type="text" label="Title" required />
            <.input field={@upload_form[:department]} type="select" label="Department" options={enum_options(Document, :department)} prompt="Choose a department" required />
            <.input field={@upload_form[:visibility]} type="select" label="Visibility" options={enum_options(Document, :visibility)} prompt="Choose a visibility" required />
            <.input field={@upload_form[:tags]} type="text" label="Tags" placeholder="comma, separated, tags" />

            <div class="flex items-center justify-between gap-4">
              <button type="button" phx-click="close_upload_modal" class="nav-chip">Cancel</button>
              <.button class="bg-green-700 hover:bg-green-800">Upload</.button>
            </div>
          </form>
        </div>
      </.modal>
    </section>
    """
  end

  defp enum_values(schema, field), do: Ecto.Enum.values(schema, field)

  defp enum_options(schema, field) do
    schema
    |> Ecto.Enum.values(field)
    |> Enum.map(&{Phoenix.Naming.humanize(&1), &1})
  end

  defp total_count(department_counts), do: department_counts |> Map.values() |> Enum.sum()

  defp filter_tab_class(selected, value) do
    if selected == value, do: "filter-tab filter-tab-active", else: "filter-tab"
  end

  defp format_date(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%d %b %Y")
  defp format_date(_), do: "-"

  defp upload_error_text(:too_large), do: "This file is too large (max 20MB)."
  defp upload_error_text(:not_accepted), do: "That file type is not supported."
  defp upload_error_text(:too_many_files), do: "Upload only one file at a time."
  defp upload_error_text(error), do: "Upload failed: #{inspect(error)}"
end
