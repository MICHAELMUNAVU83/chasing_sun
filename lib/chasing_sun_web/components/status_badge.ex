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
      "inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em]",
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

  defp tone_class(:harvesting), do: "bg-emerald-100 text-emerald-800"
  defp tone_class(:soil_turning), do: "bg-amber-100 text-amber-800"
  defp tone_class(:waiting), do: "bg-zinc-200 text-zinc-700"
end
