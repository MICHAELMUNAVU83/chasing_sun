defmodule ChasingSun.Documents.Document do
  use Ecto.Schema
  import Ecto.Changeset

  schema "documents" do
    field :department, Ecto.Enum, values: [:operations, :finance, :marketing, :other]
    field :title, :string
    field :file_url, :string
    field :visibility, Ecto.Enum,
      values: [:department_only, :leadership, :all_staff],
      default: :department_only

    field :tags, {:array, :string}, default: []
    field :content_type, :string
    field :byte_size, :integer

    belongs_to :uploaded_by, ChasingSun.Accounts.User, foreign_key: :uploaded_by_id

    timestamps(type: :utc_datetime)
  end

  def changeset(document, attrs) do
    document
    |> cast(attrs, [
      :department,
      :title,
      :file_url,
      :visibility,
      :tags,
      :content_type,
      :byte_size,
      :uploaded_by_id
    ])
    |> validate_required([:department, :title, :file_url, :visibility])
    |> validate_length(:title, max: 200)
  end
end
