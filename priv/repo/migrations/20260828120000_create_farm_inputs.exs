defmodule ChasingSun.Repo.Migrations.CreateFarmInputs do
  use Ecto.Migration

  def change do
    create table(:farm_inputs) do
      add :name, :string, null: false
      add :pack_size, :string, null: false
      add :unit_price, :decimal, precision: 12, scale: 2, null: false
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:farm_inputs, [:name, :pack_size])

    create table(:farm_input_purchases) do
      add :purchased_on, :date, null: false
      add :farm, :string
      add :notes, :text
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:farm_input_purchases, [:purchased_on])

    create table(:farm_input_purchase_lines) do
      add :purchase_id, references(:farm_input_purchases, on_delete: :delete_all), null: false
      add :farm_input_id, references(:farm_inputs, on_delete: :restrict), null: false
      add :quantity, :decimal, precision: 12, scale: 2, null: false
      add :unit_price, :decimal, precision: 12, scale: 2, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:farm_input_purchase_lines, [:purchase_id])
    create index(:farm_input_purchase_lines, [:farm_input_id])

    execute(
      """
      INSERT INTO farm_inputs (name, pack_size, unit_price, active, inserted_at, updated_at) VALUES
      ('RioMax', '1 kg', 2000, true, NOW(), NOW()), ('Dakota', '1 litre', 2600, true, NOW(), NOW()),
      ('Profile', '500 ml', 1750, true, NOW(), NOW()), ('Funguran', '1 kg', 2700, true, NOW(), NOW()),
      ('Crop Grow (High-K)', '1 litre', 1200, true, NOW(), NOW()), ('C.A.N', '50 kg', 5500, true, NOW(), NOW()),
      ('N.P.K (Triple 19)', '25 kg', 11000, true, NOW(), NOW()), ('Compostella', '200 ml', 1700, true, NOW(), NOW()),
      ('Algreen', '1 litre', 950, true, NOW(), NOW()), ('Lavender', '1 litre', 2500, true, NOW(), NOW()),
      ('Multi.K', '25 kg', 11500, true, NOW(), NOW()), ('Score', '1 litre', 8000, true, NOW(), NOW()),
      ('Yara', '50 kg', 6250, true, NOW(), NOW()), ('Kill Pest', '250 ml', 1450, true, NOW(), NOW()),
      ('Integra (sticker)', '1 litre', 5200, true, NOW(), NOW()), ('Chariot', '1 litre', 2000, true, NOW(), NOW()),
      ('Nimbicide', '500 ml', 1200, true, NOW(), NOW()), ('Oberon', '500 ml', 5500, true, NOW(), NOW()),
      ('Othello-Top', '500 ml', 3300, true, NOW(), NOW()), ('Cocoly', '5 kg', 2600, true, NOW(), NOW()),
      ('D.A.P', '50 kg', 7100, true, NOW(), NOW()), ('Ropes', '1,000 m', 600, true, NOW(), NOW()),
      ('Binding Wire', '1 kg', 200, true, NOW(), NOW()), ('Barbed Wire', '480 m', 7500, true, NOW(), NOW())
      """,
      "DELETE FROM farm_inputs"
    )
  end
end
