defmodule ChasingSunWeb.DocumentDownloadController do
  use ChasingSunWeb, :controller

  alias ChasingSun.Documents

  def show(conn, %{"id" => id}) do
    document = Documents.get_document!(id)

    if Documents.visible?(conn.assigns.current_user, document) do
      path = Path.join(Documents.upload_root(), document.file_url)

      conn
      |> put_resp_content_type(document.content_type || "application/octet-stream")
      |> send_download({:file, path}, filename: document.title)
    else
      conn
      |> put_flash(:error, "Your account does not have access to that document.")
      |> redirect(to: ~p"/documents")
    end
  end
end
