defmodule ChasingSun.Repo.Migrations.CreateDocuments do
  use Ecto.Migration

  def change do
    create table(:documents) do
      add :department, :string, null: false
      add :title, :string, null: false
      add :file_url, :string, null: false
      add :uploaded_by_id, references(:users, on_delete: :nilify_all)
      add :visibility, :string, null: false, default: "department_only"
      add :tags, {:array, :string}, null: false, default: []
      add :content_type, :string
      add :byte_size, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:documents, [:department])
    create index(:documents, [:visibility])
    create index(:documents, [:tags], using: "GIN")
  end
end
