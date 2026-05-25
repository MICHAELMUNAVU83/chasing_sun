defmodule ChasingSun.Operations.FarmVisitGreenhouseStatus do
  use Ecto.Schema
  import Ecto.Changeset

  @plant_health_options ~w(bad average good)
  @weeding_status_options ~w(poor moderate clean)

  schema "farm_visit_greenhouse_statuses" do
    field :greenhouse_sequence_no, :integer
    field :greenhouse_name, :string
    field :greenhouse_size, :string
    field :plant_health, :string
    field :weeding_status, :string
    field :foot_bath_changed_on, :date
    field :foot_bath_compliant, :boolean, default: false
    field :management_remarks, :string

    belongs_to :farm_visit_report, ChasingSun.Operations.FarmVisitReport
    belongs_to :greenhouse, ChasingSun.Operations.Greenhouse

    timestamps(type: :utc_datetime)
  end

  def changeset(status, attrs) do
    status
    |> cast(attrs, [
      :greenhouse_id,
      :greenhouse_sequence_no,
      :greenhouse_name,
      :greenhouse_size,
      :plant_health,
      :weeding_status,
      :foot_bath_changed_on,
      :foot_bath_compliant,
      :management_remarks
    ])
    |> validate_required([:greenhouse_name, :plant_health, :weeding_status])
    |> validate_inclusion(:plant_health, @plant_health_options)
    |> validate_inclusion(:weeding_status, @weeding_status_options)
    |> unique_constraint([:farm_visit_report_id, :greenhouse_id],
      name: :farm_visit_status_unique_greenhouse
    )
  end

  def plant_health_options, do: @plant_health_options
  def weeding_status_options, do: @weeding_status_options
end
