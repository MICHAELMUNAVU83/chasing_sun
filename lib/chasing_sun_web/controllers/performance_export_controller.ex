defmodule ChasingSunWeb.PerformanceExportController do
  use ChasingSunWeb, :controller

  alias ChasingSun.Accounts.Scope
  alias ChasingSun.Analytics
  alias ChasingSun.Analytics.PerformanceExport

  def show(conn, params) do
    if Scope.page_allowed?(conn.assigns.current_user, "operations") do
      report = Analytics.performance_report(export_filters(params))

      filename = export_filename(report)

      conn
      |> put_resp_content_type("application/vnd.ms-excel")
      |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
      |> send_resp(200, PerformanceExport.workbook(report))
    else
      conn
      |> put_flash(:error, "Your account does not have access to that report export.")
      |> redirect(to: ~p"/dashboard")
    end
  end

  defp export_filters(params) do
    %{
      venture_code: params["venture_code"],
      mode: params["mode"],
      greenhouse_id: params["greenhouse_id"],
      week: params["week"],
      month: params["month"],
      season_id: params["season_id"]
    }
  end

  defp export_filename(report) do
    greenhouse_slug =
      report.greenhouse_report.greenhouse_name
      |> to_string()
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/u, "-")
      |> String.trim("-")
      |> case do
        "" -> "estate"
        value -> value
      end

    "performance-#{report.filters.mode}-#{greenhouse_slug}.xls"
  end
end
