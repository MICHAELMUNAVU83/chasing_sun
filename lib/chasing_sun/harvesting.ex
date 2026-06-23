defmodule ChasingSun.Harvesting do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias ChasingSun.Accounts.User
  alias ChasingSun.Harvesting.HarvestRecord
  alias ChasingSun.Operations
  alias ChasingSun.Operations.AuditEvent
  alias ChasingSun.Operations.CropCycle
  alias ChasingSun.Repo

  def list_harvest_records(filters \\ %{}) do
    venture_code = Map.get(filters, :venture_code) || Map.get(filters, "venture_code")
    week_ending_on = Map.get(filters, :week_ending_on) || Map.get(filters, "week_ending_on")
    start_date = Map.get(filters, :start_date) || Map.get(filters, "start_date")
    end_date = Map.get(filters, :end_date) || Map.get(filters, "end_date")

    HarvestRecord
    |> join(:inner, [record], greenhouse in assoc(record, :greenhouse))
    |> maybe_filter_venture(venture_code)
    |> maybe_filter_week(week_ending_on)
    |> maybe_filter_start_date(start_date)
    |> maybe_filter_end_date(end_date)
    |> preload([record, greenhouse], ^record_preloads())
    |> order_by([record], desc: record.week_ending_on, desc: record.updated_at)
    |> Repo.all()
  end

  def recent_records(limit \\ 10) do
    HarvestRecord
    |> preload(^record_preloads())
    |> order_by([record], desc: record.week_ending_on, desc: record.updated_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def change_harvest_record(record, attrs \\ %{}), do: HarvestRecord.changeset(record, attrs)

  @doc """
  Always inserts a new harvest record. Multiple records may exist for the same
  greenhouse and week (e.g. different grades at different price points).
  """
  def create_harvest_record(attrs, actor) do
    params =
      attrs
      |> normalize_attrs(actor)
      |> ensure_crop_cycle_id()

    Multi.new()
    |> Multi.insert(:record, HarvestRecord.changeset(%HarvestRecord{}, params))
    |> Multi.run(:audit, fn repo, %{record: record} ->
      insert_audit(repo, actor, record, "harvest_record_inserted")
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{record: record}} -> {:ok, Repo.preload(record, [:crop_cycle, greenhouse: :venture])}
      {:error, :record, changeset, _} -> {:error, changeset}
    end
  end

  def upsert_harvest_record(attrs, actor) do
    params =
      attrs
      |> normalize_attrs(actor)

    existing =
      Repo.get_by(HarvestRecord,
        greenhouse_id: params["greenhouse_id"],
        week_ending_on: params["week_ending_on"]
      )

    params = ensure_crop_cycle_id(params, existing)

    Multi.new()
    |> Multi.run(:record, fn repo, _changes ->
      changeset = HarvestRecord.changeset(existing || %HarvestRecord{}, params)

      case existing do
        nil -> repo.insert(changeset)
        %HarvestRecord{} = record -> repo.update(changeset |> Map.put(:data, record))
      end
    end)
    |> Multi.run(:audit, fn repo, %{record: record} ->
      insert_audit(
        repo,
        actor,
        record,
        if(existing, do: "harvest_record_updated", else: "harvest_record_inserted")
      )
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{record: record}} -> {:ok, Repo.preload(record, [:crop_cycle, greenhouse: :venture])}
      {:error, :record, changeset, _} -> {:error, changeset}
    end
  end

  def update_harvest_record(record, attrs, actor) do
    params =
      attrs
      |> normalize_attrs(actor)
      |> ensure_crop_cycle_id(record)

    Multi.new()
    |> Multi.update(:record, HarvestRecord.changeset(record, params))
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

  defp maybe_filter_week(query, nil), do: query
  defp maybe_filter_week(query, ""), do: query

  defp maybe_filter_week(query, week_ending_on) do
    from [record, _greenhouse] in query,
      where: record.week_ending_on == ^coerce_date!(week_ending_on)
  end

  defp maybe_filter_start_date(query, nil), do: query
  defp maybe_filter_start_date(query, ""), do: query

  defp maybe_filter_start_date(query, start_date) do
    from [record, _greenhouse] in query,
      where: record.week_ending_on >= ^coerce_date!(start_date)
  end

  defp maybe_filter_end_date(query, nil), do: query
  defp maybe_filter_end_date(query, ""), do: query

  defp maybe_filter_end_date(query, end_date) do
    from [record, _greenhouse] in query,
      where: record.week_ending_on <= ^coerce_date!(end_date)
  end

  defp coerce_date!(%Date{} = date), do: date
  defp coerce_date!(date) when is_binary(date), do: Date.from_iso8601!(date)

  defp record_preloads do
    [
      :crop_cycle,
      :inserted_by_user,
      greenhouse: [:venture, crop_cycles: active_crop_cycles_query()]
    ]
  end

  defp active_crop_cycles_query do
    from(cycle in CropCycle,
      where: is_nil(cycle.archived_at),
      order_by: [desc: cycle.inserted_at]
    )
  end

  defp normalize_attrs(attrs, actor) do
    attrs
    |> Map.new(fn {key, value} -> {to_string(key), value} end)
    |> Map.put("inserted_by_user_id", actor && actor.id)
  end

  defp ensure_crop_cycle_id(params), do: ensure_crop_cycle_id(params, nil)

  defp ensure_crop_cycle_id(params, nil) do
    Map.put(
      params,
      "crop_cycle_id",
      params["crop_cycle_id"] || resolve_current_crop_cycle_id(params["greenhouse_id"])
    )
  end

  defp ensure_crop_cycle_id(params, %HarvestRecord{} = record) do
    cond do
      present?(params["crop_cycle_id"]) ->
        params

      same_greenhouse?(params["greenhouse_id"], record.greenhouse_id) ->
        Map.put(
          params,
          "crop_cycle_id",
          record.crop_cycle_id || resolve_current_crop_cycle_id(record.greenhouse_id)
        )

      true ->
        Map.put(params, "crop_cycle_id", resolve_current_crop_cycle_id(params["greenhouse_id"]))
    end
  end

  defp resolve_current_crop_cycle_id(nil), do: nil
  defp resolve_current_crop_cycle_id(""), do: nil

  defp resolve_current_crop_cycle_id(greenhouse_id) do
    greenhouse_id
    |> Operations.get_greenhouse!()
    |> Operations.resolve_current_cycle()
    |> case do
      %CropCycle{id: crop_cycle_id} -> crop_cycle_id
      _ -> nil
    end
  end

  defp same_greenhouse?(nil, _greenhouse_id), do: true
  defp same_greenhouse?("", _greenhouse_id), do: true
  defp same_greenhouse?(left, right), do: to_string(left) == to_string(right)

  defp present?(value), do: not is_nil(value) and value != ""

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
