defmodule ChasingSun.Repo.Migrations.CreateAgronomicVisits do
  use Ecto.Migration

  def up do
    create table(:agronomic_visits) do
      add :visited_on, :date, null: false
      add :agronomist_name, :string, null: false
      add :summary, :text
      add :report_file_url, :string
      add :report_file_name, :string
      add :content_type, :string
      add :byte_size, :integer
      add :inserted_by_user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:agronomic_visits, [:visited_on])
    create index(:agronomic_visits, [:inserted_by_user_id])

    # Farm-wide notifications (e.g. a late agronomic visit) are not tied to a
    # greenhouse or crop cycle.
    alter table(:operation_notifications) do
      modify :greenhouse_id, :bigint, null: true
    end

    create unique_index(:operation_notifications, [:kind, :notify_on],
             where: "greenhouse_id IS NULL",
             name: :operation_notifications_farm_wide_kind_notify_on
           )
  end

  def down do
    drop unique_index(:operation_notifications, [:kind, :notify_on],
           name: :operation_notifications_farm_wide_kind_notify_on
         )

    execute "DELETE FROM operation_notifications WHERE greenhouse_id IS NULL"

    alter table(:operation_notifications) do
      modify :greenhouse_id, :bigint, null: false
    end

    drop table(:agronomic_visits)
  end
end
