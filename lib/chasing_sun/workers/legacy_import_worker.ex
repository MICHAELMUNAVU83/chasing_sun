defmodule ChasingSun.Workers.LegacyImportWorker do
  use Oban.Worker, queue: :imports, max_attempts: 3

  alias ChasingSun.Importing

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"base_path" => base_path}}) do
    case Importing.import_now(base_path) do
      {:ok, _result} -> :ok
      {:error, :missing_files} -> :discard
      {:error, reason} -> {:error, inspect(reason)}
    end
  end
end
