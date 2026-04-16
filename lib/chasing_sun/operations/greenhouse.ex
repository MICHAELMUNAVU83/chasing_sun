defmodule ChasingSun.Operations.Greenhouse do
  use Ecto.Schema
  import Ecto.Changeset

  @size_options ["8x40", "16x40"]

  schema "greenhouses" do
    field :sequence_no, :integer
    field :name, :string
    field :size, :string
    field :tank, :string
    field :active, :boolean, default: true

    belongs_to :venture, ChasingSun.Operations.Venture
    has_many :crop_cycles, ChasingSun.Operations.CropCycle
    has_many :harvest_records, ChasingSun.Harvesting.HarvestRecord
    has_one :operation_recommendation, ChasingSun.Operations.OperationRecommendation
    has_many :operation_notifications, ChasingSun.Operations.OperationNotification

    timestamps(type: :utc_datetime)
  end

  def changeset(greenhouse, attrs) do
    greenhouse
    |> cast(attrs, [:sequence_no, :name, :size, :tank, :active, :venture_id])
    |> validate_required([:sequence_no, :name, :venture_id])
    |> validate_inclusion(:size, @size_options)
    |> unique_constraint(:sequence_no)
    |> unique_constraint(:name)
  end

  def size_options, do: @size_options
end
