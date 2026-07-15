defmodule ChasingSun.Documents do
  @moduledoc false

  import Ecto.Query, warn: false

  alias ChasingSun.Repo
  alias ChasingSun.Accounts.{Scope, User}
  alias ChasingSun.Documents.Document
  alias ChasingSun.Operations.AuditEvent

  @allowed_extensions ~w(.pdf .docx .xlsx .csv .jpg .jpeg .png .webp)
  @allowed_mime_types ~w(
    application/pdf
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    text/csv
    image/jpeg
    image/png
    image/webp
  )
  @max_upload_size 20_000_000

  def allowed_extensions, do: @allowed_extensions
  def allowed_mime_types, do: @allowed_mime_types
  def max_upload_size, do: @max_upload_size
  def upload_root, do: Application.app_dir(:chasing_sun, "priv/uploads/documents")

  @doc """
  Single visibility-scoped entry point for browsing documents. Always
  includes `all_staff` docs; `leadership` docs require the
  `bypass_document_visibility` permission (C-suite); `department_only` docs
  require either that same permission or the user's department scope.
  """
  def list_documents(user, filters \\ %{}) do
    filters = stringify_keys(filters)

    Document
    |> visibility_scope(Scope.can?(user, :bypass_document_visibility), visible_departments_for(user))
    |> maybe_filter_department(filters["department"])
    |> maybe_filter_search(filters["query"])
    |> order_by([d], asc: d.department, asc: d.title)
    |> Repo.all()
  end

  def list_documents_for_department(user, department) do
    list_documents(user, %{"department" => to_string(department)})
  end

  @doc "Departments whose department_only/leadership-scoped docs a role may see without the bypass permission."
  def visible_departments_for(%User{role: role}) when role in [:admin, :executive], do: :all
  def visible_departments_for(%User{role: :operator}), do: [:operations]
  def visible_departments_for(_user), do: []

  def get_document!(id) do
    Document
    |> Repo.get!(id)
    |> Repo.preload(:uploaded_by)
  end

  @doc "Single-record mirror of list_documents/2's visibility predicate."
  def visible?(user, %Document{} = document) do
    cond do
      Scope.can?(user, :bypass_document_visibility) -> true
      document.visibility == :all_staff -> true
      document.visibility == :department_only -> document.department in visible_departments_for(user)
      true -> false
    end
  end

  def change_document(document, attrs \\ %{}), do: Document.changeset(document, attrs)

  def create_document(attrs, actor \\ nil) do
    attrs =
      attrs
      |> stringify_keys()
      |> normalize_tags()
      |> Map.put_new("uploaded_by_id", actor && actor.id)

    %Document{}
    |> Document.changeset(attrs)
    |> Repo.insert()
    |> audit_result(actor, "document", "document_uploaded")
  end

  @doc "Removes the DB row and the underlying file on disk. Ignores a missing file."
  def delete_document(%Document{} = document, actor \\ nil) do
    case Repo.delete(document) do
      {:ok, deleted} ->
        upload_root() |> Path.join(deleted.file_url) |> File.rm()
        insert_audit(Repo, actor, "document", deleted.id, "document_deleted", %{title: deleted.title})
        {:ok, deleted}

      error ->
        error
    end
  end

  defp visibility_scope(query, true, _departments), do: query

  defp visibility_scope(query, false, departments) do
    from d in query,
      where: d.visibility == :all_staff or (d.visibility == :department_only and d.department in ^departments)
  end

  defp maybe_filter_department(query, nil), do: query
  defp maybe_filter_department(query, ""), do: query

  defp maybe_filter_department(query, department) do
    from d in query, where: d.department == ^department
  end

  defp maybe_filter_search(query, nil), do: query
  defp maybe_filter_search(query, ""), do: query

  defp maybe_filter_search(query, term) do
    tag = normalize_tag(term)

    from d in query,
      where: ilike(d.title, ^"%#{term}%") or fragment("? = ANY(?)", ^tag, d.tags)
  end

  defp normalize_tags(attrs) do
    case Map.get(attrs, "tags") do
      nil -> attrs
      tags when is_binary(tags) -> Map.put(attrs, "tags", parse_tags(tags))
      tags when is_list(tags) -> Map.put(attrs, "tags", tags |> Enum.map(&normalize_tag/1) |> Enum.uniq())
    end
  end

  defp parse_tags(tags_string) do
    tags_string
    |> String.split(",")
    |> Enum.map(&normalize_tag/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp normalize_tag(tag), do: tag |> to_string() |> String.trim() |> String.downcase()

  defp stringify_keys(attrs) when is_map(attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
  end

  defp stringify_keys(attrs), do: attrs

  defp audit_result({:ok, struct}, actor, entity_type, action) do
    insert_audit(Repo, actor, entity_type, struct.id, action, %{})
    {:ok, struct}
  end

  defp audit_result(other, _actor, _entity_type, _action), do: other

  defp insert_audit(repo, %User{id: actor_user_id}, entity_type, entity_id, action, metadata) do
    %AuditEvent{}
    |> AuditEvent.changeset(%{
      actor_user_id: actor_user_id,
      entity_type: entity_type,
      entity_id: entity_id,
      action: action,
      metadata: metadata
    })
    |> repo.insert()
  end

  defp insert_audit(_repo, _actor, _entity_type, _entity_id, _action, _metadata), do: {:ok, nil}
end
