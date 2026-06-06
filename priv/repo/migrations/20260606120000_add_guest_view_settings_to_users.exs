defmodule ChasingSun.Repo.Migrations.AddGuestViewSettingsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :allowed_pages, {:array, :string}, null: false, default: []
      add :allowed_sections, {:array, :string}, null: false, default: []
      add :allowed_venture_codes, {:array, :string}, null: false, default: []
    end
  end
end
