defmodule ChasingSun.Repo.Migrations.AddManualNextCropPlanFields do
  use Ecto.Migration

  def change do
    alter table(:operation_recommendations) do
      add :next_plant_count, :integer
      add :manually_edited, :boolean, null: false, default: false
    end
  end
end
