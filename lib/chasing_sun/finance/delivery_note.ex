defmodule ChasingSun.Finance.DeliveryNote.Item do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :product, :string
    field :quantity_mt, :decimal
    field :unit, :string
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:product, :quantity_mt, :unit])
    |> validate_required([:product, :quantity_mt])
    |> validate_number(:quantity_mt, greater_than: 0)
  end
end

defmodule ChasingSun.Finance.DeliveryNote do
  use Ecto.Schema
  import Ecto.Changeset

  alias ChasingSun.Finance.DeliveryNote.Item

  schema "delivery_notes" do
    field :order_reference, :string
    field :dispatched_on, :date
    field :signed_by, :string
    field :status, Ecto.Enum, values: [:pending, :delivered, :disputed], default: :pending

    embeds_many :items, Item, on_replace: :delete

    belongs_to :client, ChasingSun.Finance.Client

    timestamps(type: :utc_datetime)
  end

  def changeset(note, attrs) do
    note
    |> cast(attrs, [:order_reference, :dispatched_on, :signed_by, :status, :client_id])
    |> cast_embed(:items,
      with: &Item.changeset/2,
      sort_param: :items_sort,
      drop_param: :items_drop
    )
    |> validate_required([:order_reference, :client_id])
    |> validate_length(:items, min: 1, message: "must have at least one item")
    |> foreign_key_constraint(:client_id)
  end
end
