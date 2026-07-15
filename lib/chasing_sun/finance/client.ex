defmodule ChasingSun.Finance.Client do
  use Ecto.Schema
  import Ecto.Changeset

  schema "clients" do
    field :name, :string
    field :type, Ecto.Enum, values: [:packhouse, :hotel, :tea_company, :spice_company, :other]
    field :contact_person, :string
    field :phone, :string
    field :email, :string

    has_many :transactions, ChasingSun.Finance.Transaction
    has_many :invoices, ChasingSun.Finance.Invoice
    has_many :delivery_notes, ChasingSun.Finance.DeliveryNote

    timestamps(type: :utc_datetime)
  end

  def changeset(client, attrs) do
    client
    |> cast(attrs, [:name, :type, :contact_person, :phone, :email])
    |> validate_required([:name, :type])
    |> validate_length(:name, max: 200)
    |> maybe_validate_email()
  end

  defp maybe_validate_email(changeset) do
    case get_change(changeset, :email) do
      nil -> changeset
      "" -> changeset
      _ -> validate_format(changeset, :email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    end
  end
end
