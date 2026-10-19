defmodule ChasingSun.Finance.GreenhouseRevenueExportTest do
  use ExUnit.Case, async: true

  alias ChasingSun.Finance.GreenhouseRevenueExport

  test "exports every greenhouse and the totals as Excel-compatible XML" do
    rows = [
      %{greenhouse_name: "Lamu & North", yield: 125.5, revenue: Decimal.new("10040")},
      %{greenhouse_name: "Kericho", yield: 20.0, revenue: Decimal.new("1500")}
    ]

    workbook = GreenhouseRevenueExport.workbook(rows, ~D[2026-09-01], ~D[2026-09-07])

    assert workbook =~ ~s(ss:Name="Greenhouse revenue")
    assert workbook =~ "Lamu &amp; North"
    assert workbook =~ "Kericho"
    assert workbook =~ ~s(<Data ss:Type="Number">145.5</Data>)
    assert workbook =~ ~s(<Data ss:Type="Number">11540</Data>)
    assert workbook =~ "2026-09-01"
    assert workbook =~ "2026-09-07"
  end
end
