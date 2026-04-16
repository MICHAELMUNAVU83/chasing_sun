defmodule ChasingSun.Repo.Migrations.AddVarietiesToCropRules do
  use Ecto.Migration

  def up do
    alter table(:crop_rules) do
      add :varieties, {:array, :string}, null: false, default: []
    end

    execute("""
    UPDATE crop_rules
    SET varieties = CASE
      WHEN default_variety IS NULL OR btrim(default_variety) = '' THEN ARRAY[]::varchar[]
      ELSE ARRAY[default_variety]
    END
    """)
  end

  def down do
    alter table(:crop_rules) do
      remove :varieties
    end
  end
end
