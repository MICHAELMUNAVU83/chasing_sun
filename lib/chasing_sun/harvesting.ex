defmodule ChasingSun.Harvesting do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias ChasingSun.Accounts.User
  alias ChasingSun.Harvesting.HarvestRecord
  alias ChasingSun.Operations
  alias ChasingSun.Operations.AuditEvent
  alias ChasingSun.Repo

  def list_harvest_records(filters \\ %{}) do
    venture_code = Map.get(filters, :venture_code) || Map.get(filters, "venture_code")

    HarvestRecord
    |> join(:inner, [record], greenhouse in assoc(record, :greenhouse))
    |> maybe_filter_venture(venture_code)
    |> preload([record, greenhouse], [:crop_cycle, :inserted_by_user, greenhouse: :venture])
    |> order_by([record], desc: record.week_ending_on, desc: record.updated_at)
    |> Repo.all()
  end

  def recent_records(limit \\ 10) do
    HarvestRecord
    |> preload([:crop_cycle, greenhouse: :venture])
    |> order_by([record], desc: record.week_ending_on, desc: record.updated_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def change_harvest_record(record, attrs \\ %{}), do: HarvestRecord.changeset(record, attrs)

  def upsert_harvest_record(attrs, actor) do
    greenhouse = Operations.get_greenhouse!(attrs["greenhouse_id"] || attrs[:greenhouse_id])
    crop_cycle = attrs["crop_cycle_id"] || attrs[:crop_cycle_id] || Operations.current_cycle(greenhouse)
    crop_cycle_id = if is_map(crop_cycle), do: crop_cycle.id, else: crop_cycle

    params =
      attrs
      |> Map.new(fn {key, value} -> {to_string(key), value} end)
      |> Map.put("crop_cycle_id", crop_cycle_id)
      |> Map.put("inserted_by_user_id", actor && actor.id)

    existing = Repo.get_by(HarvestRecord, greenhouse_id: greenhouse.id, week_ending_on: params["week_ending_on"])

    Multi.new()
    |> Multi.run(:record, fn repo, _changes ->
      changeset = HarvestRecord.changeset(existing || %HarvestRecord{}, params)

      case existing do
        nil -> repo.insert(changeset)
        %HarvestRecord{} = record -> repo.update(changeset |> Map.put(:data, record))
      end
    end)
    |> Multi.run(:audit, fn repo, %{record: record} ->
      insert_audit(repo, actor, record, if(existing, do: "harvest_record_updated", else: "harvest_record_inserted"))
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{record: record}} -> {:ok, Repo.preload(record, [:crop_cycle, greenhouse: :venture])}
      {:error, :record, changeset, _} -> {:error, changeset}
    end
  end

  def update_harvest_record(record, attrs, actor) do
    Multi.new()
    |> Multi.update(:record, HarvestRecord.changeset(record, attrs))
    |> Multi.run(:audit, fn repo, %{record: updated_record} ->
      insert_audit(repo, actor, updated_record, "harvest_record_updated")
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{record: updated_record}} -> {:ok, updated_record}
      {:error, :record, changeset, _} -> {:error, changeset}
    end
  end

  defp maybe_filter_venture(query, nil), do: query
  defp maybe_filter_venture(query, "all"), do: query

  defp maybe_filter_venture(query, code) do
    from [record, greenhouse] in query,
      join: venture in assoc(greenhouse, :venture),
      where: venture.code == ^String.downcase(code)
  end

  defp insert_audit(repo, %User{id: actor_user_id}, record, action) do
    %AuditEvent{}
    |> AuditEvent.changeset(%{
      actor_user_id: actor_user_id,
      entity_type: "harvest_record",
      entity_id: record.id,
      action: action,
      metadata: %{greenhouse_id: record.greenhouse_id, week_ending_on: record.week_ending_on}
    })
    |> repo.insert()
  end

  defp insert_audit(_repo, _actor, _record, _action), do: {:ok, nil}
end