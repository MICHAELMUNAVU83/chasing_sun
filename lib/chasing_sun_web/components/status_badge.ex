defmodule ChasingSunWeb.Components.StatusBadge do
  use Phoenix.Component

  attr :status, :any, required: true
  attr :class, :string, default: nil

  def status_badge(assigns) do
    assigns =
      assigns
      |> assign(:normalized_status, normalize(assigns.status))
      |> assign(:label, label(assigns.status))

    ~H"""
    <span class={[
      "inline-flex items-center rounded-full border px-2 py-0.5 text-xs font-medium",
      tone_class(@normalized_status),
      @class
    ]}>
      {@label}
    </span>
    """
  end

  defp normalize(status) when status in [:harvesting, "harvesting"], do: :harvesting
  defp normalize(status) when status in [:soil_turning, "soil_turning"], do: :soil_turning
  defp normalize(_status), do: :waiting

  defp label(status) when status in [:harvesting, "harvesting"], do: "Harvesting"
  defp label(status) when status in [:soil_turning, "soil_turning"], do: "Soil Turning"
  defp label(_status), do: "Waiting"

  defp tone_class(:harvesting), do: "border-green-200 bg-green-50 text-green-700"
  defp tone_class(:soil_turning), do: "border-amber-200 bg-amber-50 text-amber-700"
  defp tone_class(:waiting), do: "border-zinc-200 bg-zinc-50 text-zinc-600"
end
