defmodule ChasingSun.Accounts.Scope do
  @moduledoc false

  alias ChasingSun.Accounts.User

  @type action ::
          :view_dashboard
          | :manage_greenhouses
          | :manage_harvest
          | :manage_crop_rules
          | :delete_greenhouses

  def can?(%User{role: role}, action) when role in [:admin, :operator, :viewer] do
    action in permissions(role)
  end

  def can?(_, _), do: false

  def permissions(:admin),
    do: [
      :view_dashboard,
      :manage_greenhouses,
      :manage_harvest,
      :manage_crop_rules,
      :delete_greenhouses
    ]

  def permissions(:operator), do: [:view_dashboard, :manage_greenhouses, :manage_harvest]
  def permissions(:viewer), do: [:view_dashboard]

  def label(%User{role: role}) when is_atom(role),
    do: role |> Atom.to_string() |> String.capitalize()

  def label(_), do: "Guest"
end
