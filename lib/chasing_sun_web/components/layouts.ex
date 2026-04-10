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

  embed_templates "layouts/*"

  def sidebar_link_class(page_title, link_title) do
    [
      "sidebar-link",
      if(page_title == link_title, do: "sidebar-link-active")
    ]
  end
end
