defmodule ChasingSun.Importing do
  @moduledoc false

  alias ChasingSun.Importing.LegacyJsonImporter
  alias ChasingSun.Workers.LegacyImportWorker

  def import_now(base_path \\ File.cwd!()) do
    LegacyJsonImporter.import_from(base_path)
  end

  def enqueue_import(base_path \\ File.cwd!()) do
    %{base_path: base_path}
    |> LegacyImportWorker.new(queue: :imports)
    |> Oban.insert()
  end
end
