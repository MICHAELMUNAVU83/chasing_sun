defmodule ChasingSun.FarmInputs.PurchaseLine do
  use Ecto.Schema
  import Ecto.Changeset

  schema "farm_input_purchase_lines" do
    field :quantity, :decimal
    field :unit_price, :decimal

    belongs_to :purchase, ChasingSun.FarmInputs.Purchase
    belongs_to :farm_input, ChasingSun.FarmInputs.Input
    timestamps(type: :utc_datetime)
  end

  def changeset(line, attrs) do
    line
    |> cast(attrs, [:farm_input_id, :quantity, :unit_price])
    |> validate_required([:farm_input_id, :quantity, :unit_price])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:unit_price, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:farm_input_id)
  end
end
