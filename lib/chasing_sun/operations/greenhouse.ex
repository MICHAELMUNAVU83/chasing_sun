defmodule ChasingSun.Operations.Greenhouse do
  use Ecto.Schema
  import Ecto.Changeset

  schema "greenhouses" do
    field :sequence_no, :integer
    field :name, :string
    field :size, :string
    field :tank, :string
    field :active, :boolean, default: true

    belongs_to :venture, ChasingSun.Operations.Venture
    has_many :crop_cycles, ChasingSun.Operations.CropCycle
    has_many :harvest_records, ChasingSun.Harvesting.HarvestRecord

    timestamps(type: :utc_datetime)
  end

  def changeset(greenhouse, attrs) do
    greenhouse
    |> cast(attrs, [:sequence_no, :name, :size, :tank, :active, :venture_id])
    |> validate_required([:sequence_no, :name, :venture_id])
    |> unique_constraint(:sequence_no)
    |> unique_constraint(:name)
  end
end