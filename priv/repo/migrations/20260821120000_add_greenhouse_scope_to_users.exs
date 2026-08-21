defmodule ChasingSun.Repo.Migrations.AddGreenhouseScopeToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :allowed_greenhouse_ids, {:array, :bigint}, null: false, default: []
    end
  end
end
