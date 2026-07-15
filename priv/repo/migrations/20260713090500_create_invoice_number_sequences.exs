defmodule ChasingSun.Repo.Migrations.CreateInvoiceNumberSequences do
  use Ecto.Migration

  def change do
    create table(:invoice_number_sequences) do
      add :year, :integer, null: false
      add :last_number, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:invoice_number_sequences, [:year])
  end
end
