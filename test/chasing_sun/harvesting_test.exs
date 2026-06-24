defmodule ChasingSun.HarvestingTest do
  use ExUnit.Case, async: true

  alias ChasingSun.Harvesting
  alias ChasingSun.Harvesting.HarvestRecord

  describe "latest_week_summary/1" do
    test "returns nil when there are no harvest records" do
      assert Harvesting.latest_week_summary([]) == nil
    end

    test "sums all harvest records for the latest week" do
      older_record = %HarvestRecord{
        week_ending_on: ~D[2026-06-07],
        actual_yield: 3.0,
        updated_at: ~U[2026-06-07 07:00:00Z]
      }

      latest_week_first_record = %HarvestRecord{
        week_ending_on: ~D[2026-06-14],
        actual_yield: 4.0,
        notes: "First pickup",
        updated_at: ~U[2026-06-14 08:00:00Z]
      }

      latest_week_second_record = %HarvestRecord{
        week_ending_on: ~D[2026-06-14],
        actual_yield: 6.5,
        notes: "Second pickup",
        updated_at: ~U[2026-06-14 12:00:00Z]
      }

      summary =
        Harvesting.latest_week_summary([
          latest_week_first_record,
          older_record,
          latest_week_second_record
        ])

      assert summary.week_ending_on == ~D[2026-06-14]
      assert summary.actual_yield == 10.5
      assert summary.notes == "Second pickup"
    end
  end
end
