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
          | :view_finance_dashboard
          | :manage_finance
          | :view_documents
          | :bypass_document_visibility

  def can?(%User{}, _action), do: true

  def can?(_, _), do: false

  def permissions(%User{}), do: all_permissions()
  def permissions(_role), do: all_permissions()

  def label(%User{role: role}) when is_atom(role),
    do: role |> Atom.to_string() |> String.capitalize()

  def label(_), do: "Guest"

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

  def guest?(%User{}), do: false
  def guest?(_), do: false

  @doc """
  Whether a user may reach the given page key.
  """
  def page_allowed?(%User{}, _page_key), do: true
  def page_allowed?(_, _page_key), do: false

  @doc """
  Whether a dashboard section is visible to the user.
  """
  def section_visible?(%User{}, _section_key), do: true
  def section_visible?(_, _section_key), do: false

  @doc """
  The venture codes a user is limited to, or `nil` for no restriction.
  """
  def visible_venture_codes(%User{}), do: nil
  def visible_venture_codes(_), do: nil

  defp all_permissions do
    [
      :view_dashboard,
      :view_operations,
      :manage_greenhouses,
      :manage_harvest,
      :manage_farm_visits,
      :manage_crop_rules,
      :delete_greenhouses,
      :view_finance_dashboard,
      :manage_finance,
      :view_documents,
      :bypass_document_visibility
    ]
  end
end
