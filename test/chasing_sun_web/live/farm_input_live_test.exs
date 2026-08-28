defmodule ChasingSunWeb.FarmInputLiveTest do
  use ExUnit.Case, async: true

  alias ChasingSunWeb.FarmInputLive.Index

  test "purchase details can change before a quantity has been selected" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, input_quantities: %{}}
    }

    params = %{
      "_target" => ["purchase", "farm"],
      "farm_input_id" => "",
      "purchase" => %{
        "farm" => "Kisii",
        "notes" => "",
        "purchased_on" => "2026-08-28"
      }
    }

    assert {:noreply, updated_socket} = Index.handle_event("price_farm_inputs", params, socket)
    assert updated_socket.assigns.input_quantities == %{}
    assert updated_socket.assigns.purchase_form.params["farm"] == "Kisii"
  end

  test "purchase detail changes preserve quantities already entered" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, input_quantities: %{"24" => "2"}}
    }

    params = %{
      "purchase" => %{"farm" => "Kisii", "purchased_on" => "2026-08-28"}
    }

    assert {:noreply, updated_socket} = Index.handle_event("price_farm_inputs", params, socket)
    assert updated_socket.assigns.input_quantities == %{"24" => "2"}
  end
end
