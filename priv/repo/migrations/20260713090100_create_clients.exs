defmodule ChasingSun.Repo.Migrations.CreateClients do
  use Ecto.Migration

  def change do
    create table(:clients) do
      add :name, :string, null: false
      add :type, :string, null: false
      add :contact_person, :string
      add :phone, :string
      add :email, :string

      timestamps(type: :utc_datetime)
    end

    create index(:clients, [:name])
    create index(:clients, [:type])
  end
end
