defmodule ChasingSun.Operations do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias ChasingSun.Repo
  alias ChasingSun.Accounts.User

  alias ChasingSun.Operations.{
    AuditEvent,
    CropCycle,
    CropPlanner,
    CropRule,
    Greenhouse,
    StatusCalculator,
    Venture
  }

  def list_ventures do
    Repo.all(from venture in Venture, order_by: [asc: venture.name])
  end

  def list_ventures_with_greenhouses do
    Repo.all(from venture in Venture, preload: [:greenhouses], order_by: [asc: venture.name])
  end

  def get_venture!(id), do: Repo.get!(Venture, id)
  def get_venture_by_code!(code), do: Repo.get_by!(Venture, code: String.downcase(code))

  def change_venture(venture, attrs \\ %{}), do: Venture.changeset(venture, attrs)

  def create_venture(attrs, actor \\ nil) do
    %Venture{}
    |> Venture.changeset(attrs)
    |> Repo.insert()
    |> audit_result(actor, "venture", "venture_saved")
  end

  def update_venture(venture, attrs, actor \\ nil) do
    venture
    |> Venture.changeset(attrs)
    |> Repo.update()
    |> audit_result(actor, "venture", "venture_saved")
  end

  def delete_venture(%Venture{} = venture, actor \\ nil) do
    Multi.new()
    |> Multi.delete(:venture, Venture.delete_changeset(venture))
    |> Multi.run(:audit, fn repo, _changes ->
      insert_audit(repo, actor, "venture", venture.id, "venture_deleted", %{name: venture.name})
    end)
    |> Repo.transaction()
    |> unwrap_transaction(:venture)
  end

  def list_crop_rules do
    Repo.all(from rule in CropRule, order_by: [asc: rule.crop_type])
  end

  def get_crop_rule!(id), do: Repo.get!(CropRule, id)

  def change_crop_rule(rule, attrs \\ %{}), do: CropRule.changeset(rule, attrs)

  def create_crop_rule(attrs, actor \\ nil) do
    %CropRule{}
    |> CropRule.changeset(attrs)
    |> Repo.insert()
    |> audit_result(actor, "crop_rule", "crop_rule_saved")
  end

  def update_crop_rule(rule, attrs, actor \\ nil) do
    rule
    |> CropRule.changeset(attrs)
    |> Repo.update()
    |> audit_result(actor, "crop_rule", "crop_rule_saved")
  end

  def list_greenhouses(filters \\ %{}) do
    venture_code = Map.get(filters, :venture_code) || Map.get(filters, "venture_code")

    greenhouse_query =
      from greenhouse in Greenhouse,
        preload: [
          :venture,
          crop_cycles:
            ^from(cycle in CropCycle,
              where: is_nil(cycle.archived_at),
              order_by: [desc: cycle.inserted_at]
            ),
          harvest_records:
            ^from(record in ChasingSun.Harvesting.HarvestRecord,
              order_by: [desc: record.week_ending_on],
              limit: 3
            )
        ],
        order_by: [asc: greenhouse.sequence_no]

    greenhouse_query
    |> maybe_filter_venture(venture_code)
    |> Repo.all()
  end

  def get_greenhouse!(id) do
    Greenhouse
    |> Repo.get!(id)
    |> Repo.preload([
      :venture,
      crop_cycles: from(cycle in CropCycle, order_by: [desc: cycle.inserted_at]),
      harvest_records:
        from(record in ChasingSun.Harvesting.HarvestRecord,
          order_by: [desc: record.week_ending_on]
        )
    ])
  end

  def change_greenhouse(greenhouse, attrs \\ %{}), do: Greenhouse.changeset(greenhouse, attrs)
  def change_crop_cycle(crop_cycle, attrs \\ %{}), do: CropCycle.changeset(crop_cycle, attrs)

  def create_greenhouse(greenhouse_attrs, cycle_attrs \\ %{}, actor \\ nil) do
    rules = list_crop_rules()

    Multi.new()
    |> Multi.insert(:greenhouse, Greenhouse.changeset(%Greenhouse{}, greenhouse_attrs))
    |> maybe_persist_cycle(:greenhouse, cycle_attrs, rules)
    |> Multi.run(:audit, fn repo, %{greenhouse: greenhouse} ->
      insert_audit(repo, actor, "greenhouse", greenhouse.id, "greenhouse_created", %{
        name: greenhouse.name
      })
    end)
    |> Repo.transaction()
    |> unwrap_transaction(:greenhouse)
  end

  def update_greenhouse(
        %Greenhouse{} = greenhouse,
        greenhouse_attrs,
        cycle_attrs \\ %{},
        actor \\ nil
      ) do
    rules = list_crop_rules()
    current_cycle = current_cycle(greenhouse)

    Multi.new()
    |> Multi.update(:greenhouse, Greenhouse.changeset(greenhouse, greenhouse_attrs))
    |> maybe_persist_existing_cycle(:greenhouse, current_cycle, cycle_attrs, rules)
    |> Multi.run(:audit, fn repo, %{greenhouse: updated_greenhouse} ->
      insert_audit(repo, actor, "greenhouse", updated_greenhouse.id, "greenhouse_updated", %{
        name: updated_greenhouse.name
      })
    end)
    |> Repo.transaction()
    |> unwrap_transaction(:greenhouse)
  end

  def delete_greenhouse(%Greenhouse{} = greenhouse, actor \\ nil) do
    Multi.new()
    |> Multi.delete(:greenhouse, greenhouse)
    |> Multi.run(:audit, fn repo, _changes ->
      insert_audit(repo, actor, "greenhouse", greenhouse.id, "greenhouse_deleted", %{
        name: greenhouse.name
      })
    end)
    |> Repo.transaction()
    |> unwrap_transaction(:greenhouse)
  end

  def current_cycle(%Greenhouse{crop_cycles: [cycle | _]}), do: refresh_status(cycle)
  def current_cycle(%Greenhouse{}), do: nil

  def refresh_status(%CropCycle{} = cycle) do
    %{cycle | status_cache: StatusCalculator.status_for_cycle(cycle)}
  end

  def crop_types do
    list_crop_rules() |> Enum.map(& &1.crop_type)
  end

  def dashboard_snapshot(filters \\ %{}) do
    greenhouses = list_greenhouses(filters)
    rules = list_crop_rules()

    statuses = Enum.map(greenhouses, &current_cycle_status/1)

    %{
      greenhouses: greenhouses,
      metrics: %{
        total_units: length(greenhouses),
        harvesting: Enum.count(statuses, &(&1 == :harvesting)),
        soil_turning: Enum.count(statuses, &(&1 == :soil_turning)),
        waiting: Enum.count(statuses, &(&1 == :waiting)),
        expected_output:
          Enum.reduce(greenhouses, 0.0, fn greenhouse, acc ->
            acc + expected_output(greenhouse, rules)
          end)
      }
    }
  end

  def ensure_venture_seeded do
    for {code, name} <- [{"cs", "Chasing Sun Core"}, {"csg", "Chasing Sun Growth"}] do
      Repo.get_by(Venture, code: code) ||
        Repo.insert!(Venture.changeset(%Venture{}, %{code: code, name: name}))
    end
  end

  def recent_audit_events(limit \\ 10) do
    Repo.all(
      from event in AuditEvent,
        preload: [:actor_user],
        order_by: [desc: event.inserted_at],
        limit: ^limit
    )
  end

  defp maybe_filter_venture(query, nil), do: query
  defp maybe_filter_venture(query, "all"), do: query
  defp maybe_filter_venture(query, ""), do: query

  defp maybe_filter_venture(query, code) do
    from greenhouse in query,
      join: venture in assoc(greenhouse, :venture),
      where: venture.code == ^String.downcase(code)
  end

  defp maybe_persist_cycle(multi, greenhouse_key, cycle_attrs, rules) do
    if meaningful_cycle_attrs?(cycle_attrs) do
      Multi.run(multi, :crop_cycle, fn repo, %{^greenhouse_key => greenhouse} ->
        normalized = normalize_cycle_attrs(cycle_attrs, greenhouse.id, rules)

        %CropCycle{}
        |> CropCycle.changeset(normalized)
        |> repo.insert()
      end)
    else
      multi
    end
  end

  defp maybe_persist_existing_cycle(multi, greenhouse_key, nil, cycle_attrs, rules) do
    maybe_persist_cycle(multi, greenhouse_key, cycle_attrs, rules)
  end

  defp maybe_persist_existing_cycle(multi, _greenhouse_key, _cycle, cycle_attrs, _rules)
       when cycle_attrs in [%{}, nil] do
    multi
  end

  defp maybe_persist_existing_cycle(multi, greenhouse_key, cycle, cycle_attrs, rules) do
    if meaningful_cycle_attrs?(cycle_attrs) do
      Multi.run(multi, :crop_cycle, fn repo, %{^greenhouse_key => greenhouse} ->
        normalized = normalize_cycle_attrs(cycle_attrs, greenhouse.id, rules)
        repo.update(CropCycle.changeset(cycle, normalized))
      end)
    else
      multi
    end
  end

  defp normalize_cycle_attrs(attrs, greenhouse_id, rules) do
    attrs
    |> Map.new(fn {key, value} -> {to_string(key), value} end)
    |> Map.put("greenhouse_id", greenhouse_id)
    |> CropPlanner.normalize_cycle_attrs(rules)
  end

  defp meaningful_cycle_attrs?(attrs) when attrs in [nil, %{}], do: false

  defp meaningful_cycle_attrs?(attrs) do
    Enum.any?(
      [
        "crop_type",
        "variety",
        "transplant_date",
        "harvest_start_date",
        "harvest_end_date",
        :crop_type
      ],
      fn key ->
        value = Map.get(attrs, key)
        value not in [nil, ""]
      end
    )
  end

  defp unwrap_transaction({:ok, result}, key), do: {:ok, Map.fetch!(result, key)}
  defp unwrap_transaction({:error, _step, changeset, _}, _key), do: {:error, changeset}

  defp audit_result({:ok, struct}, actor, entity_type, action) do
    insert_audit(Repo, actor, entity_type, struct.id, action, %{})
    {:ok, struct}
  end

  defp audit_result(other, _actor, _entity_type, _action), do: other

  defp insert_audit(repo, %User{id: actor_user_id}, entity_type, entity_id, action, metadata) do
    %AuditEvent{}
    |> AuditEvent.changeset(%{
      actor_user_id: actor_user_id,
      entity_type: entity_type,
      entity_id: entity_id,
      action: action,
      metadata: metadata
    })
    |> repo.insert()
  end

  defp insert_audit(_repo, _actor, _entity_type, _entity_id, _action, _metadata), do: {:ok, nil}

  defp current_cycle_status(greenhouse) do
    greenhouse
    |> current_cycle()
    |> case do
      nil -> :waiting
      cycle -> cycle.status_cache
    end
  end

  defp expected_output(greenhouse, rules) do
    case current_cycle(greenhouse) do
      nil -> 0.0
      cycle -> CropPlanner.expected_yield(cycle, rules)
    end
  end
end
