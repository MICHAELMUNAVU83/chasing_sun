defmodule ChasingSun.Accounts.Scope do
  @moduledoc false

  alias ChasingSun.Accounts.User

  @type action ::
          :view_dashboard
          | :view_operations
          | :manage_greenhouses
          | :manage_harvest
          | :manage_farm_visits
          | :manage_crop_rules
          | :delete_greenhouses

  def can?(%User{role: role}, action) when role in [:admin, :operator, :viewer, :guest] do
    action in permissions(role)
  end

  def can?(_, _), do: false

  def permissions(:admin),
    do: [
      :view_dashboard,
      :view_operations,
      :manage_greenhouses,
      :manage_harvest,
      :manage_farm_visits,
      :manage_crop_rules,
      :delete_greenhouses
    ]

  def permissions(:operator),
    do: [
      :view_dashboard,
      :view_operations,
      :manage_greenhouses,
      :manage_harvest,
      :manage_farm_visits
    ]

  def permissions(:viewer), do: [:view_dashboard, :view_operations]

  # Guests can only see the read-only operations dashboard — no revenue,
  # performance, or management pages.
  def permissions(:guest), do: [:view_dashboard]

  def label(%User{role: role}) when is_atom(role),
    do: role |> Atom.to_string() |> String.capitalize()

  def label(_), do: "Guest"

  ## Guest view restrictions
  #
  # Guests are limited to read-only pages and, per account, admins can
  # further restrict which pages, dashboard sections, and ventures they see.
  # Pages with create/edit/delete controls (greenhouses, harvest, farm visits)
  # and anything revenue/performance related are never offered to guests.

  # The dashboard is always available to a guest; these are the extra
  # read-only pages an admin can optionally grant.
  @guest_pages [
    %{key: "forecast", label: "Forecast"},
    %{key: "recommendations", label: "Recommendations"}
  ]

  @guest_sections [
    %{key: "summary", label: "Summary cards"},
    %{key: "status_board", label: "Greenhouse status board"},
    %{key: "charts", label: "Output & status charts"},
    %{key: "quick_view", label: "Greenhouse quick view"},
    %{key: "recommendations", label: "Crop recommendations"},
    %{key: "notifications", label: "Daily notifications"},
    %{key: "projections", label: "Next Saturday outlook"}
  ]

  def guest_pages, do: @guest_pages
  def guest_sections, do: @guest_sections
  def guest_page_keys, do: Enum.map(@guest_pages, & &1.key)
  def guest_section_keys, do: Enum.map(@guest_sections, & &1.key)

  def guest?(%User{role: :guest}), do: true
  def guest?(_), do: false

  @doc """
  Whether a user may reach the given page key. Non-guests can reach any page
  they have the operations permission for; guests are limited to the dashboard
  plus the extra pages an admin granted them.
  """
  def page_allowed?(%User{role: :guest} = user, page_key) do
    page_key == "dashboard" or page_key in (user.allowed_pages || [])
  end

  def page_allowed?(user, _page_key), do: can?(user, :view_operations)

  @doc """
  Whether a dashboard section is visible to the user. Non-guests see all
  sections; guests see only the sections an admin enabled.
  """
  def section_visible?(%User{role: :guest} = user, section_key),
    do: section_key in (user.allowed_sections || [])

  def section_visible?(_user, _section_key), do: true

  @doc """
  The venture codes a user is limited to, or `nil` for no restriction.
  """
  def visible_venture_codes(%User{role: :guest, allowed_venture_codes: codes})
      when is_list(codes) and codes != [],
      do: codes

  def visible_venture_codes(_user), do: nil
end
