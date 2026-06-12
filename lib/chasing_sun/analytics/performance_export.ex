defmodule ChasingSun.Analytics.PerformanceExport do
  @moduledoc false

  def workbook(report) do
    [
      ~s(<?xml version="1.0"?>),
      ~s(<?mso-application progid="Excel.Sheet"?>),
      ~s(<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" ),
      ~s(xmlns:o="urn:schemas-microsoft-com:office:office" ),
      ~s(xmlns:x="urn:schemas-microsoft-com:office:excel" ),
      ~s(xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">),
      worksheet("Summary", summary_rows(report)),
      worksheet("Greenhouse report", greenhouse_rows(report)),
      worksheet("Estate month", estate_rows(report)),
      worksheet("Insights", insight_rows(report)),
      "</Workbook>"
    ]
    |> IO.iodata_to_binary()
  end

  defp summary_rows(report) do
    greenhouse = report.greenhouse_report

    [
      ["Venture", export_value(report.filters.venture_code)],
      ["Mode", export_value(report.filters.mode)],
      ["Greenhouse", export_value(greenhouse.greenhouse_name)],
      ["Period", export_value(greenhouse.period_label)],
      ["Crop", export_value(greenhouse.crop_type)],
      ["Unit size", export_value(greenhouse.unit_size)],
      ["Harvested weeks", greenhouse.harvested_weeks],
      ["Kg produced", greenhouse.actual_yield],
      ["Expected kg", greenhouse.expected_yield],
      ["Variance", greenhouse.variance],
      ["Revenue", greenhouse.revenue],
      ["Exported on", Date.utc_today() |> Date.to_iso8601()]
    ]
  end

  defp greenhouse_rows(report) do
    header = ["Week ending", "Crop", "Kg produced", "Expected kg", "Variance", "Revenue", "Crop age weeks"]

    rows =
      Enum.map(report.greenhouse_report.entries, fn entry ->
        [
          entry.week_ending_on && Date.to_iso8601(entry.week_ending_on),
          export_value(entry.crop_type),
          entry.actual_yield,
          entry.expected_yield,
          entry.variance,
          entry.revenue,
          entry.crop_age_weeks
        ]
      end)

    [header | rows]
  end

  defp estate_rows(report) do
    header = [
      "Greenhouse",
      "Crop",
      "Unit size",
      "Period",
      "Kg produced",
      "Expected kg",
      "Variance",
      "Revenue",
      "Harvested weeks"
    ]

    rows =
      Enum.map(report.estate_rollup, fn row ->
        [
          export_value(row.greenhouse_name),
          export_value(row.crop_type),
          export_value(row.unit_size),
          export_value(row.period_label),
          row.actual_yield,
          row.expected_yield,
          row.variance,
          row.revenue,
          row.harvested_weeks
        ]
      end)

    [header | rows]
  end

  defp insight_rows(report) do
    [["Insights"]] ++ Enum.map(report.insights, &[&1])
  end

  defp worksheet(name, rows) do
    [
      ~s(<Worksheet ss:Name="#{xml_escape(name)}"><Table>),
      Enum.map(rows, &row/1),
      "</Table></Worksheet>"
    ]
  end

  defp row(columns) do
    ["<Row>", Enum.map(columns, &cell/1), "</Row>"]
  end

  defp cell(value) when is_integer(value) do
    ~s(<Cell><Data ss:Type="Number">#{value}</Data></Cell>)
  end

  defp cell(value) when is_float(value) do
    ~s(<Cell><Data ss:Type="Number">#{Float.round(value, 2)}</Data></Cell>)
  end

  defp cell(value) do
    ~s(<Cell><Data ss:Type="String">#{xml_escape(export_value(value))}</Data></Cell>)
  end

  defp export_value(nil), do: "-"
  defp export_value(value), do: to_string(value)

  defp xml_escape(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
