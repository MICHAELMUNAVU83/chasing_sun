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
  attr :subtitle, :any, default: "Greenhouse Operations"
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
        <p :if={@subtitle} class={@subtitle_class}>{@subtitle}</p>
        <p class={@title_class}>{@title}</p>
      </div>
    </.link>
    """
  end

  def sidebar_link_class(page_title, item) when is_map(item) do
    [
      "sidebar-link",
      if(sidebar_link_active?(page_title, item), do: "sidebar-link-active")
    ]
  end

  def sidebar_link_class(page_title, link_title) do
    sidebar_link_class(page_title, %{title: link_title})
  end

  defp sidebar_link_active?(page_title, item) do
    page_title == item.title or page_title in Map.get(item, :active_titles, []) or
      active_title_prefix?(page_title, Map.get(item, :active_title_prefixes, []))
  end

  defp active_title_prefix?(page_title, prefixes) when is_binary(page_title) do
    Enum.any?(prefixes, &String.starts_with?(page_title, &1))
  end

  defp active_title_prefix?(_, _), do: false

  def app_navigation(current_user \\ nil) do
    dashboard = %{title: "Dashboard", path: ~p"/dashboard"}

    base =
      if ChasingSunWeb.UserAuth.can?(current_user, :view_operations) do
        [
          dashboard,
          %{title: "Recommendations", path: ~p"/recommendations"},
          %{title: "Greenhouses", path: ~p"/greenhouses"},
          %{title: "Farm Visits", path: ~p"/farm-visits", label: "Visits"},
          %{title: "Harvest Records", path: ~p"/harvest-records", label: "Harvest"},
          %{title: "Performance", path: ~p"/performance"},
          %{title: "Forecast", path: ~p"/forecast"}
        ]
      else
        [dashboard]
      end

    base ++ finance_and_document_navigation(current_user)
  end

  defp finance_and_document_navigation(current_user) do
    [
      %{
        title: "Finance",
        path: ~p"/finance",
        key: :view_finance_dashboard,
        active_titles: [
          "Transactions",
          "Edit transaction",
          "Invoices",
          "New invoice",
          "Delivery notes",
          "Clients"
        ],
        active_title_prefixes: ["Invoice "]
      },
      %{title: "Documents", path: ~p"/documents", key: :view_documents}
    ]
    |> Enum.filter(&ChasingSunWeb.UserAuth.can?(current_user, &1.key))
    |> Enum.map(&Map.delete(&1, :key))
  end

  def admin_navigation do
    [
      %{title: "Ventures", path: ~p"/admin/ventures"},
      %{title: "Crop Rules", path: ~p"/admin/crop-rules"},
      %{title: "Guest Accounts", path: ~p"/admin/guests", label: "Guests"},
      %{title: "Admin Guide", path: ~p"/admin/guide"}
    ]
  end

  def sidebar_link_label(item), do: Map.get(item, :label, item.title)

  def avatar_initial(%{email: email}) when is_binary(email) and email != "" do
    email |> String.first() |> String.upcase()
  end

  def avatar_initial(_user), do: "?"

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

  defp description_for("Farm Visits"),
    do:
      "Capture daily farm visit reports, reserve tank checks, greenhouse health, and foot bath compliance in ChasingSun."

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
