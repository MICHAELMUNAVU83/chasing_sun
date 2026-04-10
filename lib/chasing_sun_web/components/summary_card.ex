defmodule ChasingSunWeb.Components.SummaryCard do
  use Phoenix.Component

  import ChasingSunWeb.FormatHelpers, only: [display_value: 1]

  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :hint, :string, default: nil
  attr :accent, :string, default: "green"
  attr :class, :string, default: nil

  def summary_card(assigns) do
    ~H"""
    <article class={[
      "metric-card relative overflow-hidden",
      accent_class(@accent),
      @class
    ]}>
      <div class="metric-label">{@title}</div>
      <div class="metric-value">{display_value(@value)}</div>
      <p :if={@hint} class="metric-hint">{@hint}</p>
    </article>
    """
  end

  defp accent_class("yellow"),
    do: "before:absolute before:inset-x-0 before:top-0 before:h-1 before:bg-[var(--brand-yellow)]"

  defp accent_class("ink"),
    do: "before:absolute before:inset-x-0 before:top-0 before:h-1 before:bg-[var(--ink)]"

  defp accent_class(_accent),
    do: "before:absolute before:inset-x-0 before:top-0 before:h-1 before:bg-[var(--brand-green)]"
end
