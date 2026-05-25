defmodule ChasingSun.Operations.FarmVisitReport do
  use Ecto.Schema
  import Ecto.Changeset

  alias ChasingSun.Operations.FarmVisitGreenhouseStatus

  @tank_level_options ~w(below_half half above_half)
  @overall_status_options ~w(on_track needs_attention critical)

  schema "farm_visit_reports" do
    field :visited_on, :date
    field :visited_by, :string
    field :reserve_tank_1_level, :string
    field :reserve_tank_2_level, :string
    field :water_reserve_compliant, :boolean, default: false
    field :overall_status, :string
    field :overall_remarks, :string
    field :sign_off, :string

    belongs_to :inserted_by_user, ChasingSun.Accounts.User

    has_many :greenhouse_statuses, FarmVisitGreenhouseStatus, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  def changeset(report, attrs) do
    report
    |> cast(attrs, [
      :visited_on,
      :visited_by,
      :reserve_tank_1_level,
      :reserve_tank_2_level,
      :water_reserve_compliant,
      :overall_status,
      :overall_remarks,
      :sign_off,
      :inserted_by_user_id
    ])
    |> validate_required([
      :visited_on,
      :visited_by,
      :reserve_tank_1_level,
      :reserve_tank_2_level,
      :overall_status
    ])
    |> validate_inclusion(:reserve_tank_1_level, @tank_level_options)
    |> validate_inclusion(:reserve_tank_2_level, @tank_level_options)
    |> validate_inclusion(:overall_status, @overall_status_options)
    |> cast_assoc(:greenhouse_statuses,
      required: true,
      with: &FarmVisitGreenhouseStatus.changeset/2
    )
    |> unique_constraint(:visited_on)
  end

  def tank_level_options, do: @tank_level_options
  def overall_status_options, do: @overall_status_options
end
