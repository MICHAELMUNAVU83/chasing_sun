defmodule ChasingSunWeb.AgronomicReportDownloadController do
  use ChasingSunWeb, :controller

  alias ChasingSun.Accounts.Scope
  alias ChasingSun.Operations

  def show(conn, %{"id" => id}) do
    visit = Operations.get_agronomic_visit!(id)

    if Scope.page_allowed?(conn.assigns.current_user, "agronomy") do
      path = Path.join(Operations.agronomic_report_upload_root(), visit.report_file_url)

      conn
      |> put_resp_content_type(visit.content_type || "application/octet-stream")
      |> send_download({:file, path},
        filename: visit.report_file_name || Path.basename(visit.report_file_url)
      )
    else
      conn
      |> put_flash(:error, "Your account does not have access to agronomic reports.")
      |> redirect(to: ~p"/dashboard")
    end
  end
end
