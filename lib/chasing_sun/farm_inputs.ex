defmodule ChasingSun.FarmInputs do
  @moduledoc "Catalog, purchasing, consumption analytics, and cost forecasting for farm inputs."

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias ChasingSun.Repo
  alias ChasingSun.FarmInputs.{Input, Purchase, PurchaseLine}

  def list_inputs do
    Repo.all(
      from input in Input, where: input.active, order_by: [asc: input.name, asc: input.pack_size]
    )
  end

  def change_input(input \\ %Input{}, attrs \\ %{}), do: Input.changeset(input, attrs)
  def get_input!(id), do: Repo.get!(Input, id)
  def create_input(attrs), do: %Input{} |> Input.changeset(attrs) |> Repo.insert()
  def update_input(%Input{} = input, attrs), do: input |> Input.changeset(attrs) |> Repo.update()

  def create_purchase(attrs, lines, user) do
    valid_lines =
      lines
      |> Enum.map(&normalize_line/1)
      |> Enum.filter(&(Decimal.compare(&1.quantity, 0) == :gt))

    if valid_lines == [] do
      {:error, :no_items}
    else
      Multi.new()
      |> Multi.insert(
        :purchase,
        Purchase.changeset(%Purchase{}, Map.put(attrs, "created_by_id", user.id))
      )
      |> Multi.run(:lines, fn repo, %{purchase: purchase} ->
        Enum.reduce_while(valid_lines, {:ok, []}, fn line, {:ok, saved} ->
          changeset =
            PurchaseLine.changeset(%PurchaseLine{}, %{
              farm_input_id: line.farm_input_id,
              quantity: line.quantity,
              unit_price: line.unit_price
            })

          case repo.insert(Ecto.Changeset.put_change(changeset, :purchase_id, purchase.id)) do
            {:ok, saved_line} -> {:cont, {:ok, [saved_line | saved]}}
            {:error, changeset} -> {:halt, {:error, changeset}}
          end
        end)
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{purchase: purchase}} -> {:ok, purchase}
        {:error, _step, reason, _changes} -> {:error, reason}
      end
    end
  end

  def analytics do
    rows =
      Repo.all(
        from line in PurchaseLine,
          join: purchase in assoc(line, :purchase),
          group_by: fragment("date_trunc('month', ?)", purchase.purchased_on),
          order_by: fragment("date_trunc('month', ?)", purchase.purchased_on),
          select: %{
            month: fragment("date_trunc('month', ?)::date", purchase.purchased_on),
            quantity: sum(line.quantity),
            cost: sum(fragment("? * ?", line.quantity, line.unit_price))
          }
      )

    month_count = length(rows)

    %{
      months: rows,
      month_count: month_count,
      average_quantity: average(rows, :quantity),
      average_cost: average(rows, :cost),
      forecast_cost: if(month_count >= 3, do: forecast(rows), else: nil)
    }
  end

  def seed_catalog do
    catalog()
    |> Enum.each(fn {name, pack_size, unit_price} ->
      %Input{}
      |> Input.changeset(%{name: name, pack_size: pack_size, unit_price: unit_price})
      |> Repo.insert(on_conflict: :nothing, conflict_target: [:name, :pack_size])
    end)
  end

  defp normalize_line(%{farm_input_id: id, quantity: quantity, unit_price: price}) do
    %{farm_input_id: id, quantity: decimal(quantity), unit_price: decimal(price)}
  end

  defp decimal(%Decimal{} = value), do: value
  defp decimal(value) when value in [nil, ""], do: Decimal.new(0)

  defp decimal(value) do
    case Decimal.parse(to_string(value)) do
      {decimal, ""} -> decimal
      _ -> Decimal.new(0)
    end
  end

  defp average([], _field), do: Decimal.new(0)

  defp average(rows, field),
    do:
      rows
      |> Enum.map(&Map.fetch!(&1, field))
      |> Enum.reduce(&Decimal.add/2)
      |> Decimal.div(length(rows))

  # A three-month moving average keeps early predictions transparent and stable.
  defp forecast(rows), do: rows |> Enum.take(-3) |> average(:cost)

  defp catalog do
    [
      {"RioMax", "1 kg", 2000},
      {"Dakota", "1 litre", 2600},
      {"Profile", "500 ml", 1750},
      {"Funguran", "1 kg", 2700},
      {"Crop Grow (High-K)", "1 litre", 1200},
      {"C.A.N", "50 kg", 5500},
      {"N.P.K (Triple 19)", "25 kg", 11000},
      {"Compostella", "200 ml", 1700},
      {"Algreen", "1 litre", 950},
      {"Lavender", "1 litre", 2500},
      {"Multi.K", "25 kg", 11500},
      {"Score", "1 litre", 8000},
      {"Yara", "50 kg", 6250},
      {"Kill Pest", "250 ml", 1450},
      {"Integra (sticker)", "1 litre", 5200},
      {"Chariot", "1 litre", 2000},
      {"Nimbicide", "500 ml", 1200},
      {"Oberon", "500 ml", 5500},
      {"Othello-Top", "500 ml", 3300},
      {"Cocoly", "5 kg", 2600},
      {"D.A.P", "50 kg", 7100},
      {"Ropes", "1,000 m", 600},
      {"Binding Wire", "1 kg", 200},
      {"Barbed Wire", "480 m", 7500}
    ]
  end
end
