defmodule ChasingSunWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use ChasingSunWeb, :controller` and
  `use ChasingSunWeb, :live_view`.
  """
  use ChasingSunWeb, :html

  @default_description "ChasingSun is a greenhouse operations platform for crop planning, harvest capture, performance tracking, and short-range forecasting."

  embed_templates "layouts/*"

  attr :navigate, :string, required: true
  attr :subtitle, :string, default: "Greenhouse Operations"
  attr :title, :string, default: "ChasingSun"
  attr :image_class, :string, default: "h-12 w-12"

  attr :title_class, :string,
    default: "text-2xl font-semibold tracking-[-0.04em] text-[var(--ink)]"

  attr :subtitle_class, :string,
    default: "text-xs uppercase tracking-[0.28em] text-[var(--muted)]"

  attr :class, :string, default: nil

  def brand_lockup(assigns) do
    ~H"""
    <.link navigate={@navigate} class={["flex items-center gap-3", @class]}>
      <img
        src={~p"/images/CHASING-SUN.png"}
        alt="ChasingSun logo"
        class={[@image_class, "rounded-2xl object-cover shadow-[0_18px_30px_rgba(63,114,47,0.18)]"]}
      />
      <div>
        <p class={@subtitle_class}>{@subtitle}</p>
        <p class={@title_class}>{@title}</p>
      </div>
    </.link>
    """
  end

  def sidebar_link_class(page_title, link_title) do
    [
      "sidebar-link",
      if(page_title == link_title, do: "sidebar-link-active")
    ]
  end

  def app_navigation do
    [
      %{title: "Dashboard", path: ~p"/dashboard"},
      %{title: "Recommendations", path: ~p"/recommendations"},
      %{title: "Greenhouses", path: ~p"/greenhouses"},
      %{title: "Harvest Records", path: ~p"/harvest-records", label: "Harvest"},
      %{title: "Performance", path: ~p"/performance"},
      %{title: "Forecast", path: ~p"/forecast"}
    ]
  end

  def admin_navigation do
    [
      %{title: "Ventures", path: ~p"/admin/ventures"},
      %{title: "Crop Rules", path: ~p"/admin/crop-rules"},
      %{title: "Admin Guide", path: ~p"/admin/guide"}
    ]
  end

  def sidebar_link_label(item), do: Map.get(item, :label, item.title)

  def seo_title(assigns) do
    case assigns[:page_title] do
      nil -> "ChasingSun"
      title -> "#{title} | ChasingSun"
    end
  end

  def seo_description(assigns) do
    assigns[:meta_description] || description_for(assigns[:page_title])
  end

  def seo_keywords(assigns) do
    assigns[:meta_keywords] ||
      "ChasingSun, greenhouse operations, harvest management, crop forecasting, greenhouse dashboard, farm analytics"
  end

  def seo_url(assigns) do
    assigns[:meta_url] || ChasingSunWeb.Endpoint.url()
  end

  def seo_image(assigns) do
    assigns[:meta_image] || absolute_url(~p"/images/CHASING-SUN.png")
  end

  def seo_robots(assigns) do
    assigns[:meta_robots] ||
      if(assigns[:current_user], do: "noindex, nofollow", else: "index, follow")
  end

  def seo_type(assigns) do
    assigns[:meta_type] || if(assigns[:current_user], do: "website", else: "website")
  end

  defp description_for("Dashboard"),
    do:
      "Track greenhouse status, expected output, and recommended next crop actions from the ChasingSun control room."

  defp description_for("Recommendations"),
    do:
      "Review immediate greenhouse crop rotation recommendations, nursery windows, and transplant dates in ChasingSun."

  defp description_for("Greenhouses"),
    do:
      "Manage greenhouse units, venture assignments, and active crop cycles that drive ChasingSun forecasting and analytics."

  defp description_for("Harvest Records"),
    do:
      "Capture weekly greenhouse harvest actuals in ChasingSun to keep performance and revenue reporting accurate."

  defp description_for("Performance"),
    do:
      "Compare actual yield, expected output, and revenue estimates across greenhouse operations in ChasingSun."

  defp description_for("Forecast"),
    do:
      "Review ChasingSun eight-week greenhouse output forecasts, peak weeks, and upcoming crop rotation recommendations."

  defp description_for("Crop Rules"),
    do:
      "Configure ChasingSun crop durations, expected yields, and KES pricing models used by planning and analytics."

  defp description_for("Ventures"),
    do:
      "Manage venture names and codes used by greenhouse ownership, filtering, and reporting across ChasingSun."

  defp description_for("Admin Guide"),
    do:
      "Read the ChasingSun admin guide for page-by-page instructions on what to review, edit, and troubleshoot."

  defp description_for(_page_title), do: @default_description

  defp absolute_url(path), do: ChasingSunWeb.Endpoint.url() <> path
end
