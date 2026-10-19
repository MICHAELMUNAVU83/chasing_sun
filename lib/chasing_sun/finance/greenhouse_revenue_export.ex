defmodule ChasingSun.Finance.GreenhouseRevenueExport do
  @moduledoc false

  def workbook(rows, from_date, to_date) do
    total_yield = Enum.reduce(rows, 0.0, &((&1.yield || 0.0) + &2))
    total_revenue = Enum.reduce(rows, Decimal.new(0), &Decimal.add(&1.revenue, &2))

    [
      ~s(<?xml version="1.0"?>),
      ~s(<?mso-application progid="Excel.Sheet"?>),
      ~s(<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" ),
      ~s(xmlns:o="urn:schemas-microsoft-com:office:office" ),
      ~s(xmlns:x="urn:schemas-microsoft-com:office:excel" ),
      ~s(xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">),
      worksheet("Greenhouse revenue", [
        ["Greenhouse revenue report"],
        ["From", Date.to_iso8601(from_date)],
        ["To", Date.to_iso8601(to_date)],
        [],
        ["Greenhouse", "Harvested (kg)", "Revenue (KES)"]
        | Enum.map(rows, &[&1.greenhouse_name, &1.yield, &1.revenue]) ++
            [["Total", total_yield, total_revenue]]
      ]),
      "</Workbook>"
    ]
    |> IO.iodata_to_binary()
  end

  defp worksheet(name, rows) do
    [
      ~s(<Worksheet ss:Name="#{xml_escape(name)}"><Table>),
      Enum.map(rows, &row/1),
      "</Table></Worksheet>"
    ]
  end

  defp row(columns), do: ["<Row>", Enum.map(columns, &cell/1), "</Row>"]

  defp cell(%Decimal{} = value), do: number_cell(Decimal.to_string(value, :normal))
  defp cell(value) when is_integer(value), do: number_cell(value)
  defp cell(value) when is_float(value), do: number_cell(value)

  defp cell(value) do
    ~s(<Cell><Data ss:Type="String">#{value |> to_string() |> xml_escape()}</Data></Cell>)
  end

  defp number_cell(value), do: ~s(<Cell><Data ss:Type="Number">#{value}</Data></Cell>)

  defp xml_escape(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
