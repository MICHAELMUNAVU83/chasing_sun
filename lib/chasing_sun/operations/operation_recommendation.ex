defmodule ChasingSun.Operations.OperationRecommendation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "operation_recommendations" do
    field :current_crop, :string
    field :next_crop, :string
    field :next_variety, :string
    field :recommendation_kind, :string, default: "rotation"
    field :note, :string, default: ""
    field :nursery_date, :date
    field :transplant_date, :date
    field :harvest_start_date, :date
    field :harvest_end_date, :date
    field :soil_recovery_end_date, :date
    field :generated_on, :date

    belongs_to :greenhouse, ChasingSun.Operations.Greenhouse
    belongs_to :crop_cycle, ChasingSun.Operations.CropCycle

    timestamps(type: :utc_datetime)
  end

  def changeset(recommendation, attrs) do
    recommendation
    |> cast(attrs, [
      :greenhouse_id,
      :crop_cycle_id,
      :current_crop,
      :next_crop,
      :next_variety,
      :recommendation_kind,
      :note,
      :nursery_date,
      :transplant_date,
      :harvest_start_date,
      :harvest_end_date,
      :soil_recovery_end_date,
      :generated_on
    ])
    |> validate_required([
      :greenhouse_id,
      :current_crop,
      :next_crop,
      :recommendation_kind,
      :note,
      :generated_on
    ])
    |> unique_constraint(:greenhouse_id)
  end
end
