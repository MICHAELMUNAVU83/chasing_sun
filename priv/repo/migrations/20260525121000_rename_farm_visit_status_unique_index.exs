defmodule ChasingSun.Repo.Migrations.RenameFarmVisitStatusUniqueIndex do
  use Ecto.Migration

  def up do
    execute """
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM pg_class
        WHERE relkind = 'i'
          AND relname = 'farm_visit_greenhouse_statuses_farm_visit_report_id_greenhouse_'
      )
      AND NOT EXISTS (
        SELECT 1
        FROM pg_class
        WHERE relkind = 'i'
          AND relname = 'farm_visit_status_unique_greenhouse'
      )
      THEN
        ALTER INDEX farm_visit_greenhouse_statuses_farm_visit_report_id_greenhouse_
        RENAME TO farm_visit_status_unique_greenhouse;
      END IF;
    END $$;
    """
  end

  def down do
    :ok
  end
end
