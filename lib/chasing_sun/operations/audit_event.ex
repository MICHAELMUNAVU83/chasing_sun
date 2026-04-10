defmodule ChasingSun.Operations.AuditEvent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "audit_events" do
    field :entity_type, :string
    field :entity_id, :integer
    field :action, :string
    field :metadata, :map, default: %{}

    belongs_to :actor_user, ChasingSun.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(audit_event, attrs) do
    audit_event
    |> cast(attrs, [:actor_user_id, :entity_type, :entity_id, :action, :metadata])
    |> validate_required([:entity_type, :action])
  end
end