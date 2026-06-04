defmodule ChasingSun.Repo.Migrations.AllowMultipleHarvestRecordsPerWeek do
  use Ecto.Migration

  def change do
    # Allow more than one harvest record for the same greenhouse and week
    # (e.g. different grades sold at different price points).
    drop unique_index(:harvest_records, [:greenhouse_id, :week_ending_on])
    create index(:harvest_records, [:greenhouse_id, :week_ending_on])

    alter table(:harvest_records) do
      add :grade, :string
    end
  end
end
