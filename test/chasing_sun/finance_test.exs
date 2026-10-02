defmodule ChasingSun.FinanceTest do
  use ExUnit.Case, async: true

  alias ChasingSun.Finance

  describe "sale_revenue/1" do
    test "uses the price captured on the harvest record" do
      revenue =
        Finance.sale_revenue(%{
          actual_yield: 125.5,
          price_per_kg: 80.0,
          rule_price: 60.0
        })

      assert Decimal.equal?(revenue, Decimal.new("10040"))
    end

    test "falls back to the crop rule price" do
      revenue =
        Finance.sale_revenue(%{
          actual_yield: 20.0,
          price_per_kg: nil,
          rule_price: 75.0
        })

      assert Decimal.equal?(revenue, Decimal.new("1500"))
    end
  end

  describe "validate_harvest_revenue_range/2" do
    test "accepts periods of one week or longer" do
      assert {:ok, ~D[2026-09-01], ~D[2026-09-07]} =
               Finance.validate_harvest_revenue_range("2026-09-01", "2026-09-07")
    end

    test "rejects periods shorter than one week" do
      assert {:error, "Select a period of at least one week."} =
               Finance.validate_harvest_revenue_range("2026-09-01", "2026-09-06")
    end

    test "rejects a backwards period" do
      assert {:error, "End date must be after start date."} =
               Finance.validate_harvest_revenue_range("2026-09-07", "2026-09-01")
    end
  end
end
