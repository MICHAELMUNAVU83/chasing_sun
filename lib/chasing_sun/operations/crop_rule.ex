defmodule ChasingSun.Operations.CropRule do
  use Ecto.Schema
  import Ecto.Changeset

  schema "crop_rules" do
    field :crop_type, :string
    field :nursery_days, :integer
    field :days_to_harvest, :integer
    field :harvest_period_days, :integer
    field :default_variety, :string
    field :forced_size, :string
    field :expected_yield_1000, :float
    field :expected_yield_2000, :float
    field :flat_expected_yield, :float
    field :price_per_unit, :float
    field :active, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  def changeset(crop_rule, attrs) do
    crop_rule
    |> cast(attrs, [
      :crop_type,
      :nursery_days,
      :days_to_harvest,
      :harvest_period_days,
      :default_variety,
      :forced_size,
      :expected_yield_1000,
      :expected_yield_2000,
      :flat_expected_yield,
      :price_per_unit,
      :active
    ])
    |> validate_required([:crop_type, :price_per_unit])
    |> unique_constraint(:crop_type)
  end
end