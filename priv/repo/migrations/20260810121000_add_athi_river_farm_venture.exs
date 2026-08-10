defmodule ChasingSun.Repo.Migrations.AddAthiRiverFarmVenture do
  use Ecto.Migration

  @doc """
  Adds the Athi River Farm venture to existing databases. Greenhouses and volume
  targets for it are entered through the admin UI.
  """
  def up do
    execute """
    INSERT INTO ventures (code, name, inserted_at, updated_at)
    VALUES ('athi', 'Athi River Farm', NOW(), NOW())
    ON CONFLICT (code) DO NOTHING
    """
  end

  def down do
    # Only removes the venture when nothing was attached to it.
    execute """
    DELETE FROM ventures
    WHERE code = 'athi'
      AND NOT EXISTS (SELECT 1 FROM greenhouses WHERE greenhouses.venture_id = ventures.id)
    """
  end
end
