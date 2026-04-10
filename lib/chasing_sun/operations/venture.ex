defmodule ChasingSun.Operations.Venture do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ventures" do
    field :code, :string
    field :name, :string

    has_many :greenhouses, ChasingSun.Operations.Greenhouse

    timestamps(type: :utc_datetime)
  end

  def changeset(venture, attrs) do
    venture
    |> cast(attrs, [:code, :name])
    |> validate_required([:code, :name])
    |> update_change(:code, &String.downcase/1)
    |> unique_constraint(:code)
  end
end