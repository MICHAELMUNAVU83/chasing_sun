defmodule ChasingSun.Accounts.Scope do
  @moduledoc false

  alias ChasingSun.Accounts.User

  @type action ::
          :view_dashboard
          | :view_operations
          | :manage_greenhouses
          | :manage_harvest
          | :manage_farm_visits
          | :manage_agronomic_visits
          | :manage_crop_rules
          | :delete_greenhouses
          | :view_finance_dashboard
          | :manage_finance
          | :view_documents
          | :bypass_document_visibility

  def can?(%User{} = user, action), do: action in permissions(user)

  def can?(_, _), do: false

  def permissions(%User{role: role}), do: permissions(role)
  def permissions(:admin), do: all_permissions()

  def permissions(:operator),
    do: [
      :view_dashboard,
      :view_operations,
      :manage_greenhouses,
      :manage_harvest,
      :manage_farm_visits,
      :manage_agronomic_visits
    ]

  def permissions(:viewer), do: [:view_dashboard, :view_operations]
  def permissions(:guest), do: [:view_dashboard]
  def permissions(:accountant), do: [:view_finance_dashboard, :manage_finance]

  def permissions(:executive),
    do: [:view_finance_dashboard, :view_documents, :bypass_document_visibility]

  @doc """
  Operations-only manager, locked to their assigned venture codes via
  `visible_venture_codes/1`. Finance and Documents are intentionally excluded
  until those records carry a venture scope of their own — see AUTH.md.
  """
  def permissions(:venture_manager),
    do: [
      :view_dashboard,
      :view_operations,
      :manage_greenhouses,
      :manage_harvest,
      :manage_farm_visits,
      :manage_agronomic_visits
    ]

  def permissions(_role), do: []

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

  def guest?(%User{role: :guest}), do: true
  def guest?(%User{}), do: false
  def guest?(_), do: false

  @doc """
  Whether a user may reach the given page key.
  """
  def page_allowed?(%User{role: :guest, allowed_pages: pages}, page_key),
    do: page_key in (pages || [])

  def page_allowed?(%User{} = user, _page_key), do: can?(user, :view_operations)
  def page_allowed?(_, _page_key), do: false

  @doc """
  Whether a dashboard section is visible to the user.
  """
  def section_visible?(%User{role: :guest, allowed_sections: sections}, section_key),
    do: section_key in (sections || [])

  def section_visible?(%User{}, _section_key), do: true
  def section_visible?(_, _section_key), do: false

  @doc """
  The venture codes a user is limited to, or `nil` for no restriction.
  """
  def visible_venture_codes(%User{role: role, allowed_venture_codes: codes})
      when role in [:guest, :venture_manager] and is_list(codes) and codes != [],
      do: codes

  def visible_venture_codes(%User{}), do: nil
  def visible_venture_codes(_), do: nil

  @doc "The greenhouse ids a guest is explicitly limited to, or `nil`."
  def visible_greenhouse_ids(%User{role: :guest, allowed_greenhouse_ids: ids})
      when is_list(ids) and ids != [],
      do: ids

  def visible_greenhouse_ids(_), do: nil

  @doc "Filters that must be applied to every operations query for this user."
  def operations_filters(%User{} = user) do
    case visible_greenhouse_ids(user) do
      ids when is_list(ids) -> %{greenhouse_ids: ids}
      nil -> maybe_venture_filters(visible_venture_codes(user))
    end
  end

  def operations_filters(_), do: %{}

  def operations_filters(user, venture_code) do
    filters = operations_filters(user)

    if venture_code in [nil, "", "all"],
      do: filters,
      else: Map.put(filters, :venture_code, venture_code)
  end

  defp maybe_venture_filters(nil), do: %{}
  defp maybe_venture_filters(codes), do: %{venture_codes: codes}

  defp all_permissions do
    [
      :view_dashboard,
      :view_operations,
      :manage_greenhouses,
      :manage_harvest,
      :manage_farm_visits,
      :manage_agronomic_visits,
      :manage_crop_rules,
      :delete_greenhouses,
      :view_finance_dashboard,
      :manage_finance,
      :view_documents,
      :bypass_document_visibility
    ]
  end
end
