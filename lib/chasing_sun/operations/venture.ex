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
    |> update_change(:code, &(String.trim(&1) |> String.downcase()))
    |> update_change(:name, &String.trim/1)
    |> validate_format(:code, ~r/^[a-z0-9_-]+$/,
      message: "must use lowercase letters, numbers, dashes, or underscores"
    )
    |> unique_constraint(:code)
  end

  def delete_changeset(venture) do
    venture
    |> change()
    |> no_assoc_constraint(:greenhouses)
  end
end
