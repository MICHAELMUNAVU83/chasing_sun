defmodule ChasingSun.Finance.Invoice.LineItem do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :description, :string
    field :quantity, :decimal
    field :unit_price, :decimal
    field :total, :decimal
  end

  def changeset(line_item, attrs) do
    line_item
    |> cast(attrs, [:description, :quantity, :unit_price, :total])
    |> validate_required([:description, :quantity, :unit_price])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:unit_price, greater_than_or_equal_to: 0)
    |> put_computed_total()
  end

  defp put_computed_total(changeset) do
    quantity = get_field(changeset, :quantity)
    unit_price = get_field(changeset, :unit_price)

    if quantity && unit_price do
      put_change(changeset, :total, Decimal.mult(quantity, unit_price))
    else
      changeset
    end
  end
end

defmodule ChasingSun.Finance.Invoice do
  use Ecto.Schema
  import Ecto.Changeset

  alias ChasingSun.Finance.Invoice.LineItem

  # Real PDF rendering (e.g. ChromicPDF) is a follow-up; the interim
  # mechanism is a print-styled HTML page (InvoicesLive.Show) + browser print.
  schema "invoices" do
    field :invoice_number, :string
    field :status, Ecto.Enum, values: [:draft, :sent, :paid, :overdue], default: :draft
    field :due_date, :date
    field :business_line, Ecto.Enum, values: [:horticulture, :commodity]
    field :pdf_url, :string

    embeds_many :line_items, LineItem, on_replace: :delete

    belongs_to :client, ChasingSun.Finance.Client
    belongs_to :transaction, ChasingSun.Finance.Transaction

    timestamps(type: :utc_datetime)
  end

  def changeset(invoice, attrs) do
    invoice
    |> cast(attrs, [
      :invoice_number,
      :status,
      :due_date,
      :business_line,
      :pdf_url,
      :client_id,
      :transaction_id
    ])
    |> cast_embed(:line_items,
      with: &LineItem.changeset/2,
      sort_param: :line_items_sort,
      drop_param: :line_items_drop
    )
    |> validate_required([:client_id, :due_date, :business_line])
    |> validate_length(:line_items, min: 1, message: "must have at least one line item")
    |> foreign_key_constraint(:client_id)
    |> unique_constraint(:invoice_number)
  end

  @doc "Grand total across all line items, computed on read (not persisted)."
  def total(%__MODULE__{line_items: line_items}) do
    Enum.reduce(line_items, Decimal.new(0), fn item, acc ->
      Decimal.add(acc, item.total || Decimal.new(0))
    end)
  end
end
