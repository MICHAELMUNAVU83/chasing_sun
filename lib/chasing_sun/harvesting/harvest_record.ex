defmodule ChasingSun.Harvesting.HarvestRecord do
  use Ecto.Schema
  import Ecto.Changeset

  schema "harvest_records" do
    field :week_ending_on, :date
    field :actual_yield, :float
    field :price_per_kg, :float
    field :grade, :string
    field :notes, :string

    belongs_to :greenhouse, ChasingSun.Operations.Greenhouse
    belongs_to :crop_cycle, ChasingSun.Operations.CropCycle
    belongs_to :inserted_by_user, ChasingSun.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(harvest_record, attrs) do
    harvest_record
    |> cast(attrs, [
      :greenhouse_id,
      :crop_cycle_id,
      :week_ending_on,
      :actual_yield,
      :price_per_kg,
      :grade,
      :notes,
      :inserted_by_user_id
    ])
    |> validate_required([:greenhouse_id, :week_ending_on, :actual_yield])
    |> validate_number(:actual_yield, greater_than_or_equal_to: 0)
    |> validate_number(:price_per_kg, greater_than_or_equal_to: 0)
  end
end
