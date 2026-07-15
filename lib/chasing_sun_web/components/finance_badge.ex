defmodule ChasingSunWeb.Components.FinanceBadge do
  use Phoenix.Component

  attr :status, :any, required: true
  attr :class, :string, default: nil

  def finance_badge(assigns) do
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

  defp normalize(status) when status in [:draft, "draft"], do: :draft
  defp normalize(status) when status in [:sent, "sent"], do: :sent
  defp normalize(status) when status in [:paid, "paid"], do: :paid
  defp normalize(status) when status in [:overdue, "overdue"], do: :overdue
  defp normalize(status) when status in [:pending, "pending"], do: :pending
  defp normalize(status) when status in [:delivered, "delivered"], do: :delivered
  defp normalize(status) when status in [:disputed, "disputed"], do: :disputed
  defp normalize(_status), do: :unknown

  defp label(status) when status in [:draft, "draft"], do: "Draft"
  defp label(status) when status in [:sent, "sent"], do: "Sent"
  defp label(status) when status in [:paid, "paid"], do: "Paid"
  defp label(status) when status in [:overdue, "overdue"], do: "Overdue"
  defp label(status) when status in [:pending, "pending"], do: "Pending"
  defp label(status) when status in [:delivered, "delivered"], do: "Delivered"
  defp label(status) when status in [:disputed, "disputed"], do: "Disputed"
  defp label(status), do: status |> to_string() |> Phoenix.Naming.humanize()

  defp tone_class(:draft), do: "border-zinc-200 bg-zinc-50 text-zinc-600"
  defp tone_class(:sent), do: "border-amber-200 bg-amber-50 text-amber-700"
  defp tone_class(:paid), do: "border-green-200 bg-green-50 text-green-700"
  defp tone_class(:overdue), do: "border-rose-200 bg-rose-50 text-rose-700"
  defp tone_class(:pending), do: "border-zinc-200 bg-zinc-50 text-zinc-600"
  defp tone_class(:delivered), do: "border-green-200 bg-green-50 text-green-700"
  defp tone_class(:disputed), do: "border-rose-200 bg-rose-50 text-rose-700"
  defp tone_class(:unknown), do: "border-zinc-200 bg-zinc-50 text-zinc-600"
end
