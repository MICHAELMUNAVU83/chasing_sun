defmodule ChasingSunWeb.FinanceExportController do
  use ChasingSunWeb, :controller

  alias ChasingSun.Accounts.Scope
  alias ChasingSun.Finance
  alias ChasingSun.Finance.GreenhouseRevenueExport

  def show(conn, params) do
    if Scope.can?(conn.assigns.current_user, :view_finance_dashboard) do
      export(conn, params)
    else
      conn
      |> put_flash(:error, "Your account does not have access to Finance.")
      |> redirect(to: ~p"/dashboard")
    end
  end

  defp export(conn, params) do
    case Finance.validate_harvest_revenue_range(params["date_from"], params["date_to"]) do
      {:ok, from_date, to_date} ->
        rows =
          Finance.all_greenhouse_revenue(
            from_date,
            to_date,
            Scope.operations_filters(conn.assigns.current_user)
          )
          |> Enum.filter(&(to_string(&1.greenhouse_id) == to_string(params["greenhouse_id"])))

        filename = "greenhouse-revenue-#{export_slug(rows)}-#{from_date}-to-#{to_date}.xls"

        conn
        |> put_resp_content_type("application/vnd.ms-excel")
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
        |> send_resp(200, GreenhouseRevenueExport.workbook(rows, from_date, to_date))

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/finance")
    end
  end

  defp export_slug([%{greenhouse_name: name} | _]) do
    name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")
  end

  defp export_slug([]), do: "greenhouse"
end
