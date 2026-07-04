defmodule ChasingSun.Operations.CropPlannerTest do
  use ExUnit.Case, async: true

  alias ChasingSun.Operations.CropPlanner

  describe "next_crop_recommendation/2" do
    test "rotates Chasing Sun capsicum houses to Local Cucumber" do
      assert CropPlanner.next_crop_recommendation("Capsicum", "cs") == "Local Cucumber"
    end

    test "keeps the default capsicum rotation outside Chasing Sun" do
      assert CropPlanner.next_crop_recommendation("Capsicum", "csg") == "Cucumber"
      assert CropPlanner.next_crop_recommendation("Capsicum") == "Cucumber"
    end
  end
end
