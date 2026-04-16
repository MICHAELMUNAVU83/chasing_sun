defmodule ChasingSun.Operations.OperationNotification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "operation_notifications" do
    field :kind, :string
    field :message, :string
    field :notify_on, :date
    field :sent_at, :utc_datetime
    field :metadata, :map, default: %{}

    belongs_to :greenhouse, ChasingSun.Operations.Greenhouse
    belongs_to :crop_cycle, ChasingSun.Operations.CropCycle

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [
      :greenhouse_id,
      :crop_cycle_id,
      :kind,
      :message,
      :notify_on,
      :sent_at,
      :metadata
    ])
    |> validate_required([:greenhouse_id, :crop_cycle_id, :kind, :message, :notify_on, :sent_at])
    |> unique_constraint([:greenhouse_id, :crop_cycle_id, :kind])
  end
end
