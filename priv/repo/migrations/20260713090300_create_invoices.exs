defmodule ChasingSun.Repo.Migrations.CreateInvoices do
  use Ecto.Migration

  def change do
    create table(:invoices) do
      add :client_id, references(:clients, on_delete: :restrict), null: false
      add :transaction_id, references(:transactions, on_delete: :nilify_all)
      add :invoice_number, :string, null: false
      add :status, :string, null: false, default: "draft"
      add :due_date, :date
      add :business_line, :string, null: false
      add :line_items, {:array, :map}, null: false, default: []
      add :pdf_url, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:invoices, [:invoice_number])
    create index(:invoices, [:client_id])
    create index(:invoices, [:status])
    create index(:invoices, [:due_date])
  end
end
