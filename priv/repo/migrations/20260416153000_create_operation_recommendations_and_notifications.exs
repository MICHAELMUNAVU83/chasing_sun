defmodule ChasingSun.Repo.Migrations.CreateOperationRecommendationsAndNotifications do
  use Ecto.Migration

  def change do
    create table(:operation_recommendations) do
      add :greenhouse_id, references(:greenhouses, on_delete: :delete_all), null: false
      add :crop_cycle_id, references(:crop_cycles, on_delete: :nilify_all)
      add :current_crop, :string, null: false
      add :next_crop, :string, null: false
      add :next_variety, :string
      add :recommendation_kind, :string, null: false, default: "rotation"
      add :note, :text, null: false, default: ""
      add :nursery_date, :date
      add :transplant_date, :date
      add :harvest_start_date, :date
      add :harvest_end_date, :date
      add :soil_recovery_end_date, :date
      add :generated_on, :date, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:operation_recommendations, [:greenhouse_id])
    create index(:operation_recommendations, [:crop_cycle_id])
    create index(:operation_recommendations, [:generated_on])

    create table(:operation_notifications) do
      add :greenhouse_id, references(:greenhouses, on_delete: :delete_all), null: false
      add :crop_cycle_id, references(:crop_cycles, on_delete: :nilify_all)
      add :kind, :string, null: false
      add :message, :text, null: false
      add :notify_on, :date, null: false
      add :sent_at, :utc_datetime, null: false
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:operation_notifications, [:greenhouse_id])
    create index(:operation_notifications, [:crop_cycle_id])
    create index(:operation_notifications, [:notify_on])
    create unique_index(:operation_notifications, [:greenhouse_id, :crop_cycle_id, :kind])
  end
end
