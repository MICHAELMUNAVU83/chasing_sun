defmodule ChasingSunWeb.Components.SummaryCard do
  use Phoenix.Component

  import ChasingSunWeb.FormatHelpers, only: [display_value: 1]

  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :hint, :string, default: nil
  # Accepted for backwards compatibility but no longer rendered — all stat
  # cards now use one uniform flat style.
  attr :accent, :string, default: nil
  attr :class, :string, default: nil

  def summary_card(assigns) do
    ~H"""
    <article class={["metric-card", @class]}>
      <div class="metric-label">{@title}</div>
      <div class="metric-value">{display_value(@value)}</div>
      <p :if={@hint} class="metric-hint">{@hint}</p>
    </article>
    """
  end
end
