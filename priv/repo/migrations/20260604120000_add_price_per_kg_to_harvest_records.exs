defmodule ChasingSun.Repo.Migrations.AddPricePerKgToHarvestRecords do
  use Ecto.Migration

  def change do
    alter table(:harvest_records) do
      add :price_per_kg, :float
    end
  end
end
