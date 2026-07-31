defmodule ChasingSun.Repo.Migrations.AddSoilRecoveryDaysToCropRules do
  use Ecto.Migration

  def up do
    alter table(:crop_rules) do
      add :soil_recovery_days, :integer, null: false, default: 30
    end
  end

  def down do
    alter table(:crop_rules) do
      remove :soil_recovery_days
    end
  end
end
