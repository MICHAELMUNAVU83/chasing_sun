defmodule ChasingSun.Finance.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field :type, Ecto.Enum, values: [:revenue, :expense]
    field :business_line, Ecto.Enum, values: [:horticulture, :commodity]
    field :amount, :decimal
    field :currency, :string, default: "KES"
    field :description, :string
    field :category, :string
    field :occurred_on, :date

    belongs_to :client, ChasingSun.Finance.Client
    belongs_to :recorded_by, ChasingSun.Accounts.User, foreign_key: :recorded_by_id

    timestamps(type: :utc_datetime)
  end

  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :type,
      :business_line,
      :amount,
      :currency,
      :description,
      :category,
      :occurred_on,
      :client_id,
      :recorded_by_id
    ])
    |> validate_required([:type, :business_line, :amount, :occurred_on])
    |> validate_number(:amount, greater_than: 0)
    |> foreign_key_constraint(:client_id)
  end
end
