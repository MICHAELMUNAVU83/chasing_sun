defmodule ChasingSun.Operations.CropCycle do
  use Ecto.Schema
  import Ecto.Changeset

  schema "crop_cycles" do
    field :crop_type, :string
    field :variety, :string
    field :plant_count, :integer
    field :nursery_date, :date
    field :transplant_date, :date
    field :harvest_start_date, :date
    field :harvest_end_date, :date
    field :soil_recovery_end_date, :date
    field :status_cache, Ecto.Enum, values: [:harvesting, :soil_turning, :waiting], default: :waiting
    field :archived_at, :utc_datetime

    belongs_to :greenhouse, ChasingSun.Operations.Greenhouse
    has_many :harvest_records, ChasingSun.Harvesting.HarvestRecord

    timestamps(type: :utc_datetime)
  end

  def changeset(crop_cycle, attrs) do
    crop_cycle
    |> cast(attrs, [
      :greenhouse_id,
      :crop_type,
      :variety,
      :plant_count,
      :nursery_date,
      :transplant_date,
      :harvest_start_date,
      :harvest_end_date,
      :soil_recovery_end_date,
      :status_cache,
      :archived_at
    ])
    |> validate_required([:greenhouse_id, :crop_type])
    |> validate_number(:plant_count, greater_than_or_equal_to: 0)
    |> validate_inclusion(:status_cache, [:harvesting, :soil_turning, :waiting])
  end
end