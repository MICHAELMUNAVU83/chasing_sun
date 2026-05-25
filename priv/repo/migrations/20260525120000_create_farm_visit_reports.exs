defmodule ChasingSun.Repo.Migrations.CreateFarmVisitReports do
  use Ecto.Migration

  def change do
    create table(:farm_visit_reports) do
      add :visited_on, :date, null: false
      add :visited_by, :string, null: false
      add :reserve_tank_1_level, :string, null: false
      add :reserve_tank_2_level, :string, null: false
      add :water_reserve_compliant, :boolean, null: false, default: false
      add :overall_status, :string, null: false
      add :overall_remarks, :text
      add :sign_off, :string
      add :inserted_by_user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:farm_visit_reports, [:visited_on])
    create index(:farm_visit_reports, [:inserted_by_user_id])
    create index(:farm_visit_reports, [:overall_status])

    create table(:farm_visit_greenhouse_statuses) do
      add :farm_visit_report_id, references(:farm_visit_reports, on_delete: :delete_all),
        null: false

      add :greenhouse_id, references(:greenhouses, on_delete: :nilify_all)
      add :greenhouse_sequence_no, :integer
      add :greenhouse_name, :string, null: false
      add :greenhouse_size, :string
      add :plant_health, :string, null: false
      add :weeding_status, :string, null: false
      add :foot_bath_changed_on, :date
      add :foot_bath_compliant, :boolean, null: false, default: false
      add :management_remarks, :text

      timestamps(type: :utc_datetime)
    end

    create index(:farm_visit_greenhouse_statuses, [:farm_visit_report_id])
    create index(:farm_visit_greenhouse_statuses, [:greenhouse_id])

    create unique_index(
             :farm_visit_greenhouse_statuses,
             [
               :farm_visit_report_id,
               :greenhouse_id
             ],
             name: :farm_visit_status_unique_greenhouse
           )
  end
end
