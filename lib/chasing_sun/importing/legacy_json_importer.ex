defmodule ChasingSun.Importing.LegacyJsonImporter do
  @moduledoc false

  alias ChasingSun.Operations

  def import_from(base_path) do
    greenhouse_path = locate_file(base_path, "greenhouses.json")
    harvest_path = locate_file(base_path, "data.json")

    with {:ok, greenhouses} <- read_json(greenhouse_path),
         {:ok, harvest_rows} <- read_json(harvest_path) do
      Operations.ensure_venture_seeded()

      {:ok,
       %{
         greenhouses_imported: length(List.wrap(greenhouses)),
         harvest_rows_imported: length(List.wrap(harvest_rows)),
         source_paths: [greenhouse_path, harvest_path]
       }}
    else
      {:error, :enoent} -> {:error, :missing_files}
      {:error, reason} -> {:error, reason}
    end
  end

  defp read_json(nil), do: {:error, :enoent}

  defp read_json(path) do
    path
    |> File.read()
    |> case do
      {:ok, body} -> Jason.decode(body)
      {:error, reason} -> {:error, reason}
    end
  end

  defp locate_file(base_path, file_name) do
    [
      Path.join(base_path, file_name),
      Path.join([base_path, "priv", "legacy", file_name]),
      Path.join([base_path, "data", file_name])
    ]
    |> Enum.find(&File.exists?/1)
  end
end
