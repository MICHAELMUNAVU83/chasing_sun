defmodule ChasingSun.FarmInputs.Purchase do
  use Ecto.Schema
  import Ecto.Changeset

  schema "farm_input_purchases" do
    field :purchased_on, :date
    field :farm, :string
    field :notes, :string

    belongs_to :created_by, ChasingSun.Accounts.User
    has_many :lines, ChasingSun.FarmInputs.PurchaseLine
    timestamps(type: :utc_datetime)
  end

  def changeset(purchase, attrs) do
    purchase
    |> cast(attrs, [:purchased_on, :farm, :notes, :created_by_id])
    |> validate_required([:purchased_on])
  end
end
