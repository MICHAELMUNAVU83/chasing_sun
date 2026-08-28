defmodule ChasingSun.FarmInputs.Input do
  use Ecto.Schema
  import Ecto.Changeset

  schema "farm_inputs" do
    field :name, :string
    field :pack_size, :string
    field :unit_price, :decimal
    field :active, :boolean, default: true

    has_many :purchase_lines, ChasingSun.FarmInputs.PurchaseLine, foreign_key: :farm_input_id
    timestamps(type: :utc_datetime)
  end

  def changeset(input, attrs) do
    input
    |> cast(attrs, [:name, :pack_size, :unit_price, :active])
    |> update_change(:name, &String.trim/1)
    |> update_change(:pack_size, &String.trim/1)
    |> validate_required([:name, :pack_size, :unit_price])
    |> validate_number(:unit_price, greater_than_or_equal_to: 0)
    |> unique_constraint([:name, :pack_size])
  end
end
