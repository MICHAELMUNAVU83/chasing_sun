defmodule ChasingSun.Repo.Migrations.CreateDeliveryNotes do
  use Ecto.Migration

  def change do
    create table(:delivery_notes) do
      add :order_reference, :string, null: false
      add :client_id, references(:clients, on_delete: :restrict), null: false
      add :items, {:array, :map}, null: false, default: []
      add :dispatched_on, :date
      add :signed_by, :string
      add :status, :string, null: false, default: "pending"

      timestamps(type: :utc_datetime)
    end

    create index(:delivery_notes, [:client_id])
    create index(:delivery_notes, [:status])
    create index(:delivery_notes, [:dispatched_on])
  end
end
