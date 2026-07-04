defmodule ChasingSun.Operations.ExpansionEngineTest do
  use ExUnit.Case, async: true

  alias ChasingSun.Operations.{CropCycle, CropRule, ExpansionEngine, Greenhouse}

  describe "continuous_harvest_lead_days/2" do
    test "uses construction time plus the selected crop path to first harvest" do
      rules = [
        %CropRule{crop_type: "Cucumber", days_to_harvest: 45, active: true},
        %CropRule{crop_type: "Capsicum", nursery_days: 45, days_to_harvest: 90, active: true},
        %CropRule{crop_type: "Local Cucumber", days_to_harvest: 60, active: true},
        %CropRule{crop_type: "Asparagus", days_to_harvest: 365, active: true}
      ]

      assert ExpansionEngine.continuous_harvest_lead_days(rules, "Local Cucumber") == 74
    end
  end

  describe "continuous_harvest_risk/3" do
    test "alerts before the last Local Cucumber harvest ends when no replacement starts in time" do
      today = ~D[2026-07-04]
      cycle = cycle(1, "Local Cucumber", ~D[2026-04-01], ~D[2026-09-01])

      risk =
        ExpansionEngine.continuous_harvest_risk(
          [{greenhouse(1, "Lamu"), cycle}],
          crop_rules(),
          today
        )

      assert risk.greenhouse.name == "Lamu"
      assert risk.cycle.id == 1
      assert risk.lead_days == 74
      assert risk.replacement_required_by == ~D[2026-09-01]
    end

    test "does not alert when a Local Cucumber replacement harvest begins before the pipeline closes" do
      today = ~D[2026-07-04]
      current = cycle(1, "Local Cucumber", ~D[2026-04-01], ~D[2026-09-01])
      replacement = cycle(2, "Local Cucumber", ~D[2026-08-20], ~D[2027-01-20])

      refute ExpansionEngine.continuous_harvest_risk(
               [
                 {greenhouse(1, "Lamu"), current},
                 {greenhouse(2, "Kericho"), replacement}
               ],
               crop_rules(),
               today
             )
    end

    test "does alert when only a non-Local Cucumber replacement starts before the pipeline closes" do
      today = ~D[2026-07-04]
      current = cycle(1, "Local Cucumber", ~D[2026-04-01], ~D[2026-09-01])
      replacement = cycle(2, "Cucumber", ~D[2026-08-20], ~D[2027-01-20])

      assert ExpansionEngine.continuous_harvest_risk(
               [
                 {greenhouse(1, "Lamu"), current},
                 {greenhouse(2, "Kericho"), replacement}
               ],
               crop_rules(),
               today
             )
    end

    test "does not alert while there is still enough lead time to plan the replacement" do
      today = ~D[2026-07-04]
      cycle = cycle(1, "Local Cucumber", ~D[2026-04-01], ~D[2026-12-15])

      refute ExpansionEngine.continuous_harvest_risk(
               [{greenhouse(1, "Lamu"), cycle}],
               crop_rules(),
               today
             )
    end
  end

  defp crop_rules do
    [
      %CropRule{crop_type: "Cucumber", days_to_harvest: 45, active: true},
      %CropRule{crop_type: "Capsicum", nursery_days: 45, days_to_harvest: 90, active: true},
      %CropRule{crop_type: "Local Cucumber", days_to_harvest: 60, active: true}
    ]
  end

  defp greenhouse(id, name) do
    %Greenhouse{id: id, name: name, size: "16x40", active: true}
  end

  defp cycle(id, crop_type, harvest_start_date, harvest_end_date) do
    %CropCycle{
      id: id,
      crop_type: crop_type,
      harvest_start_date: harvest_start_date,
      harvest_end_date: harvest_end_date
    }
  end
end
