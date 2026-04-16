defmodule ChasingSun.Repo.Migrations.AddRoleAndOperationsTables do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :role, :string, null: false, default: "viewer"
    end

    create table(:ventures) do
      add :code, :string, null: false
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:ventures, [:code])

    create table(:greenhouses) do
      add :sequence_no, :integer, null: false
      add :name, :string, null: false
      add :size, :string
      add :tank, :string
      add :active, :boolean, null: false, default: true
      add :venture_id, references(:ventures, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:greenhouses, [:sequence_no])
    create unique_index(:greenhouses, [:name])
    create index(:greenhouses, [:venture_id])

    create table(:crop_rules) do
      add :crop_type, :string, null: false
      add :nursery_days, :integer
      add :days_to_harvest, :integer
      add :harvest_period_days, :integer
      add :default_variety, :string
      add :forced_size, :string
      add :expected_yield_1000, :float
      add :expected_yield_2000, :float
      add :flat_expected_yield, :float
      add :price_per_unit, :float, null: false
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:crop_rules, [:crop_type])

    create table(:crop_cycles) do
      add :greenhouse_id, references(:greenhouses, on_delete: :delete_all), null: false
      add :crop_type, :string, null: false
      add :variety, :string
      add :plant_count, :integer
      add :nursery_date, :date
      add :transplant_date, :date
      add :harvest_start_date, :date
      add :harvest_end_date, :date
      add :soil_recovery_end_date, :date
      add :status_cache, :string, null: false, default: "waiting"
      add :archived_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:crop_cycles, [:greenhouse_id])

    create table(:harvest_records) do
      add :greenhouse_id, references(:greenhouses, on_delete: :delete_all), null: false
      add :crop_cycle_id, references(:crop_cycles, on_delete: :nilify_all)
      add :week_ending_on, :date, null: false
      add :actual_yield, :float, null: false
      add :notes, :text
      add :inserted_by_user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:harvest_records, [:greenhouse_id, :week_ending_on])
    create index(:harvest_records, [:crop_cycle_id])
    create index(:harvest_records, [:inserted_by_user_id])

    create table(:audit_events) do
      add :actor_user_id, references(:users, on_delete: :nilify_all)
      add :entity_type, :string, null: false
      add :entity_id, :integer
      add :action, :string, null: false
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:audit_events, [:actor_user_id])
    create index(:audit_events, [:entity_type, :entity_id])
    create index(:audit_events, [:action])
  end
end
