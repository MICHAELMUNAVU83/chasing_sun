defmodule ChasingSun.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :type, :string, null: false
      add :business_line, :string, null: false
      add :amount, :decimal, null: false
      add :currency, :string, null: false, default: "KES"
      add :description, :string
      add :category, :string
      add :occurred_on, :date, null: false
      add :client_id, references(:clients, on_delete: :nilify_all)
      add :recorded_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:transactions, [:occurred_on])
    create index(:transactions, [:business_line, :type])
    create index(:transactions, [:client_id])
  end
end
