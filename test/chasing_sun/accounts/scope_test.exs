defmodule ChasingSun.Accounts.ScopeTest do
  use ExUnit.Case, async: true

  alias ChasingSun.Accounts.{Scope, User}

  describe "visible_venture_codes/1" do
    test "limits a guest to their selected ventures" do
      guest = %User{role: :guest, allowed_venture_codes: ["cs", "athi"]}

      assert Scope.visible_venture_codes(guest) == ["cs", "athi"]
    end

    test "treats a guest with no selected ventures as unrestricted" do
      guest = %User{role: :guest, allowed_venture_codes: []}

      assert Scope.visible_venture_codes(guest) == nil
    end

    test "does not restrict non-guest users" do
      user = %User{role: :admin, allowed_venture_codes: ["cs"]}

      assert Scope.visible_venture_codes(user) == nil
    end
  end

  describe "operations_filters/1" do
    test "uses explicit greenhouse assignments before venture assignments" do
      guest = %User{
        role: :guest,
        allowed_venture_codes: ["cs"],
        allowed_greenhouse_ids: [2, 5]
      }

      assert Scope.operations_filters(guest) == %{greenhouse_ids: [2, 5]}
    end

    test "uses venture assignments when no greenhouses are selected" do
      guest = %User{role: :guest, allowed_venture_codes: ["cs"], allowed_greenhouse_ids: []}

      assert Scope.operations_filters(guest) == %{venture_codes: ["cs"]}
    end

    test "leaves an unassigned guest unrestricted" do
      assert Scope.operations_filters(%User{role: :guest}) == %{}
    end
  end

  describe "guest access" do
    test "allows only explicitly granted pages and dashboard sections" do
      guest = %User{
        role: :guest,
        allowed_pages: ["forecast"],
        allowed_sections: ["summary"]
      }

      assert Scope.page_allowed?(guest, "forecast")
      refute Scope.page_allowed?(guest, "recommendations")
      assert Scope.section_visible?(guest, "summary")
      refute Scope.section_visible?(guest, "notifications")
    end

    test "keeps guest accounts read-only" do
      guest = %User{role: :guest}

      assert Scope.can?(guest, :view_dashboard)
      refute Scope.can?(guest, :manage_greenhouses)
      refute Scope.can?(guest, :manage_harvest)
    end
  end

  describe "venture_manager access" do
    test "grants operations edit access, but not finance or documents" do
      manager = %User{role: :venture_manager}

      assert Scope.can?(manager, :manage_greenhouses)
      assert Scope.can?(manager, :manage_harvest)
      assert Scope.can?(manager, :manage_farm_visits)
      assert Scope.can?(manager, :manage_agronomic_visits)
      refute Scope.can?(manager, :manage_finance)
      refute Scope.can?(manager, :view_documents)
      refute Scope.can?(manager, :manage_crop_rules)
      refute Scope.can?(manager, :delete_greenhouses)
    end

    test "is locked to its assigned venture codes" do
      manager = %User{role: :venture_manager, allowed_venture_codes: ["athi"]}

      assert Scope.visible_venture_codes(manager) == ["athi"]
      assert Scope.operations_filters(manager) == %{venture_codes: ["athi"]}
    end

    test "is unrestricted when given no venture codes" do
      manager = %User{role: :venture_manager, allowed_venture_codes: []}

      assert Scope.visible_venture_codes(manager) == nil
    end
  end
end
