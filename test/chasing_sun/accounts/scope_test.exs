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
end
