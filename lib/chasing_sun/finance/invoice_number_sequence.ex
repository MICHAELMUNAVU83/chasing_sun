defmodule ChasingSun.Finance.InvoiceNumberSequence do
  use Ecto.Schema
  import Ecto.Changeset

  schema "invoice_number_sequences" do
    field :year, :integer
    field :last_number, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  def changeset(sequence, attrs) do
    sequence
    |> cast(attrs, [:year, :last_number])
    |> validate_required([:year, :last_number])
    |> unique_constraint(:year)
  end
end
