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
    FarmVisitGreenhouseStatus,
    FarmVisitReport,
    Greenhouse,
    OperationNotification,
    OperationRecommendation,
    RecommendationEngine,
    StatusCalculator,
    Venture
  }

  @operations_topic "operations:updates"

  def operations_topic, do: @operations_topic

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

  def change_crop_rule(rule, attrs \\ %{}) do
    rule
    |> CropRule.changeset(with_crop_rule_form_defaults(rule, attrs))
  end

  def create_crop_rule(attrs, actor \\ nil) do
    %CropRule{}
    |> CropRule.changeset(attrs)
    |> Repo.insert()
    |> tap(&maybe_enqueue_recommendation_refresh/1)
    |> audit_result(actor, "crop_rule", "crop_rule_saved")
  end

  def update_crop_rule(rule, attrs, actor \\ nil) do
    rule
    |> CropRule.changeset(attrs)
    |> Repo.update()
    |> tap(&maybe_enqueue_recommendation_refresh/1)
    |> audit_result(actor, "crop_rule", "crop_rule_saved")
  end

  def list_greenhouses(filters \\ %{}) do
    venture_code = Map.get(filters, :venture_code) || Map.get(filters, "venture_code")

    greenhouse_query =
      from greenhouse in Greenhouse,
        preload: [
          :venture,
          :operation_recommendation,
          operation_notifications:
            ^from(notification in OperationNotification,
              order_by: [desc: notification.notify_on, desc: notification.inserted_at],
              limit: 5
            ),
          crop_cycles:
            ^from(cycle in CropCycle,
              where: is_nil(cycle.archived_at),
              order_by: [desc: cycle.inserted_at]
            ),
          harvest_records:
            ^from(record in ChasingSun.Harvesting.HarvestRecord,
              order_by: [desc: record.week_ending_on, desc: record.updated_at]
            )
        ],
        order_by: [asc: greenhouse.sequence_no]

    greenhouse_query
    |> maybe_filter_venture(venture_code)
    |> maybe_filter_venture_codes(Map.get(filters, :venture_codes))
    |> Repo.all()
  end

  def get_greenhouse!(id) do
    Greenhouse
    |> Repo.get!(id)
    |> Repo.preload([
      :venture,
      :operation_recommendation,
      operation_notifications:
        from(notification in OperationNotification,
          order_by: [desc: notification.notify_on, desc: notification.inserted_at],
          limit: 10
        ),
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
    |> tap(&maybe_enqueue_recommendation_refresh/1)
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
    |> tap(&maybe_enqueue_recommendation_refresh/1)
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
    |> tap(&maybe_enqueue_recommendation_refresh/1)
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

  def crop_varieties(crop_type, rules \\ nil)

  def crop_varieties(crop_type, _rules) when crop_type in [nil, ""], do: []

  def crop_varieties(crop_type, nil) do
    crop_type
    |> crop_rule_for()
    |> crop_rule_varieties()
  end

  def crop_varieties(crop_type, rules) do
    rules
    |> crop_rule_for(crop_type)
    |> crop_rule_varieties()
  end

  def default_variety_for_crop(crop_type, rules \\ nil)

  def default_variety_for_crop(crop_type, _rules) when crop_type in [nil, ""], do: nil

  def default_variety_for_crop(crop_type, nil) do
    crop_type
    |> crop_rule_for()
    |> crop_rule_default_variety()
  end

  def default_variety_for_crop(crop_type, rules) do
    rules
    |> crop_rule_for(crop_type)
    |> crop_rule_default_variety()
  end

  def list_operation_recommendations(filters \\ %{}) do
    venture_code = Map.get(filters, :venture_code) || Map.get(filters, "venture_code")

    query =
      from recommendation in OperationRecommendation,
        join: greenhouse in assoc(recommendation, :greenhouse),
        join: venture in assoc(greenhouse, :venture),
        order_by: [asc: greenhouse.sequence_no]

    query
    |> maybe_filter_joined_venture(venture_code)
    |> maybe_filter_joined_venture_codes(Map.get(filters, :venture_codes))
    |> Repo.all()
    |> Repo.preload(greenhouse: :venture)
  end

  def recent_operation_notifications(limit \\ 8, filters \\ %{}) do
    venture_code = Map.get(filters, :venture_code) || Map.get(filters, "venture_code")

    query =
      from notification in OperationNotification,
        join: greenhouse in assoc(notification, :greenhouse),
        join: venture in assoc(greenhouse, :venture),
        order_by: [desc: notification.notify_on, desc: notification.inserted_at],
        limit: ^limit

    query
    |> maybe_filter_joined_venture(venture_code)
    |> maybe_filter_joined_venture_codes(Map.get(filters, :venture_codes))
    |> Repo.all()
    |> Repo.preload(greenhouse: :venture)
  end

  def refresh_daily_operations(today \\ Date.utc_today()) do
    rules = list_crop_rules()

    result =
      list_greenhouses()
      |> Enum.map(&sync_greenhouse(&1, rules, today))

    broadcast_refresh(today)
    result
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

  def list_farm_visit_reports(filters \\ %{}) do
    limit = Map.get(filters, :limit) || Map.get(filters, "limit")

    FarmVisitReport
    |> order_by([report], desc: report.visited_on, desc: report.updated_at)
    |> maybe_limit_query(limit)
    |> Repo.all()
    |> Repo.preload(farm_visit_report_preloads())
  end

  def get_farm_visit_report!(id) do
    FarmVisitReport
    |> Repo.get!(id)
    |> Repo.preload(farm_visit_report_preloads())
  end

  def get_farm_visit_report_by_date(date) do
    with {:ok, date} <- coerce_date(date),
         %FarmVisitReport{} = report <- Repo.get_by(FarmVisitReport, visited_on: date) do
      Repo.preload(report, farm_visit_report_preloads())
    else
      _ -> nil
    end
  end

  def change_farm_visit_report(report, attrs \\ %{}) do
    FarmVisitReport.changeset(report, normalize_farm_visit_report_attrs(attrs, nil))
  end

  def upsert_farm_visit_report(attrs, actor) do
    params = normalize_farm_visit_report_attrs(attrs, actor)

    case farm_visit_report_date(params) do
      {:ok, visited_on} ->
        case Repo.get_by(FarmVisitReport, visited_on: visited_on) do
          nil -> create_farm_visit_report(params, actor)
          report -> update_farm_visit_report(report, params, actor)
        end

      :error ->
        create_farm_visit_report(params, actor)
    end
  end

  def update_farm_visit_report(%FarmVisitReport{} = report, attrs, actor) do
    report = Repo.preload(report, :greenhouse_statuses)

    params =
      attrs
      |> normalize_farm_visit_report_attrs(actor)
      |> merge_existing_greenhouse_status_ids(report.greenhouse_statuses)

    Multi.new()
    |> Multi.update(:report, FarmVisitReport.changeset(report, params))
    |> Multi.run(:audit, fn repo, %{report: updated_report} ->
      insert_audit(
        repo,
        actor,
        "farm_visit_report",
        updated_report.id,
        "farm_visit_report_updated",
        %{
          visited_on: updated_report.visited_on
        }
      )
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{report: updated_report}} ->
        {:ok, Repo.preload(updated_report, farm_visit_report_preloads())}

      {:error, :report, changeset, _} ->
        {:error, changeset}
    end
  end

  defp create_farm_visit_report(attrs, actor) do
    Multi.new()
    |> Multi.insert(:report, FarmVisitReport.changeset(%FarmVisitReport{}, attrs))
    |> Multi.run(:audit, fn repo, %{report: report} ->
      insert_audit(repo, actor, "farm_visit_report", report.id, "farm_visit_report_inserted", %{
        visited_on: report.visited_on
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{report: report}} ->
        {:ok, Repo.preload(report, farm_visit_report_preloads())}

      {:error, :report, changeset, _} ->
        {:error, changeset}
    end
  end

  defp farm_visit_report_preloads do
    [
      :inserted_by_user,
      greenhouse_statuses: {farm_visit_greenhouse_status_query(), [greenhouse: :venture]}
    ]
  end

  defp farm_visit_greenhouse_status_query do
    from status in FarmVisitGreenhouseStatus,
      order_by: [asc: status.greenhouse_sequence_no, asc: status.greenhouse_name]
  end

  defp maybe_limit_query(query, nil), do: query
  defp maybe_limit_query(query, ""), do: query

  defp maybe_limit_query(query, limit) when is_integer(limit) and limit > 0 do
    from source in query, limit: ^limit
  end

  defp maybe_limit_query(query, limit) when is_binary(limit) do
    case Integer.parse(limit) do
      {parsed_limit, ""} -> maybe_limit_query(query, parsed_limit)
      _ -> query
    end
  end

  defp maybe_limit_query(query, _limit), do: query

  defp normalize_farm_visit_report_attrs(attrs, actor) do
    attrs
    |> stringify_keys()
    |> Map.update("greenhouse_statuses", [], &normalize_greenhouse_status_attrs/1)
    |> Map.put("inserted_by_user_id", actor && actor.id)
  end

  defp normalize_greenhouse_status_attrs(nil), do: []

  defp normalize_greenhouse_status_attrs(statuses) when is_map(statuses) do
    statuses
    |> Enum.sort_by(fn {index, _attrs} -> status_index(index) end)
    |> Enum.map(fn {_index, attrs} -> stringify_keys(attrs) end)
  end

  defp normalize_greenhouse_status_attrs(statuses) when is_list(statuses) do
    Enum.map(statuses, &stringify_keys/1)
  end

  defp merge_existing_greenhouse_status_ids(params, existing_statuses) do
    existing_by_greenhouse_id =
      existing_statuses
      |> Enum.reject(&is_nil(&1.greenhouse_id))
      |> Map.new(&{to_string(&1.greenhouse_id), &1.id})

    existing_by_name = Map.new(existing_statuses, &{&1.greenhouse_name, &1.id})

    statuses =
      params
      |> Map.get("greenhouse_statuses", [])
      |> Enum.map(fn status ->
        existing_id =
          existing_by_greenhouse_id[to_string(status["greenhouse_id"])] ||
            existing_by_name[status["greenhouse_name"]]

        if status["id"] in [nil, ""] and existing_id do
          Map.put(status, "id", existing_id)
        else
          status
        end
      end)

    Map.put(params, "greenhouse_statuses", statuses)
  end

  defp farm_visit_report_date(params) do
    params
    |> Map.get("visited_on")
    |> coerce_date()
  end

  defp coerce_date(%Date{} = date), do: {:ok, date}

  defp coerce_date(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, date} -> {:ok, date}
      {:error, _reason} -> :error
    end
  end

  defp coerce_date(_date), do: :error

  defp stringify_keys(attrs) when is_map(attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
  end

  defp stringify_keys(attrs), do: attrs

  defp status_index(index) do
    case Integer.parse(to_string(index)) do
      {parsed_index, ""} -> parsed_index
      _ -> 0
    end
  end

  defp maybe_filter_venture(query, nil), do: query
  defp maybe_filter_venture(query, "all"), do: query
  defp maybe_filter_venture(query, ""), do: query

  defp maybe_filter_venture(query, code) do
    from greenhouse in query,
      join: venture in assoc(greenhouse, :venture),
      where: venture.code == ^String.downcase(code)
  end

  defp maybe_filter_joined_venture(query, nil), do: query
  defp maybe_filter_joined_venture(query, "all"), do: query
  defp maybe_filter_joined_venture(query, ""), do: query

  defp maybe_filter_joined_venture(query, code) do
    from [source, greenhouse, venture] in query, where: venture.code == ^String.downcase(code)
  end

  defp maybe_filter_venture_codes(query, codes) when is_list(codes) and codes != [] do
    codes = Enum.map(codes, &String.downcase/1)

    from greenhouse in query,
      join: venture in assoc(greenhouse, :venture),
      where: venture.code in ^codes
  end

  defp maybe_filter_venture_codes(query, _codes), do: query

  defp maybe_filter_joined_venture_codes(query, codes) when is_list(codes) and codes != [] do
    codes = Enum.map(codes, &String.downcase/1)
    from [_source, _greenhouse, venture] in query, where: venture.code in ^codes
  end

  defp maybe_filter_joined_venture_codes(query, _codes), do: query

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

  defp with_crop_rule_form_defaults(rule, attrs) do
    attrs =
      attrs
      |> Map.new(fn {key, value} -> {to_string(key), value} end)

    cond do
      Map.has_key?(attrs, "varieties_text") ->
        attrs

      Map.has_key?(attrs, "varieties") ->
        Map.put(attrs, "varieties_text", CropRule.varieties_to_text(attrs["varieties"]))

      true ->
        Map.put(attrs, "varieties_text", CropRule.varieties_to_text(rule.varieties || []))
    end
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

  defp crop_rule_for(crop_type) do
    Repo.get_by(CropRule, crop_type: crop_type)
  end

  defp crop_rule_for(rules, crop_type) do
    Enum.find(rules, &(&1.crop_type == crop_type))
  end

  defp crop_rule_varieties(nil), do: []

  defp crop_rule_varieties(rule) do
    rule.varieties
    |> List.wrap()
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end

  defp crop_rule_default_variety(nil), do: nil

  defp crop_rule_default_variety(rule) do
    rule.default_variety || List.first(crop_rule_varieties(rule))
  end

  defp sync_greenhouse(%Greenhouse{} = greenhouse, rules, today) do
    case current_cycle(greenhouse) do
      nil ->
        delete_recommendation_for_greenhouse(greenhouse.id)
        %{greenhouse_id: greenhouse.id, recommendation: nil, notifications: []}

      %CropCycle{} = cycle ->
        cycle = sync_status_cache(cycle, today)
        {cycle, rotation_notification} = maybe_rotate_cycle(greenhouse, cycle, rules, today)
        cycle = sync_status_cache(cycle, today)
        recommendation = upsert_recommendation(greenhouse, cycle, rules, today)

        recommendation_notification =
          maybe_insert_recommendation_notification(greenhouse, cycle, recommendation, today)

        %{
          greenhouse_id: greenhouse.id,
          recommendation: recommendation,
          notifications:
            Enum.reject([rotation_notification, recommendation_notification], &is_nil/1)
        }
    end
  end

  defp sync_status_cache(%CropCycle{} = cycle, today) do
    status = StatusCalculator.status_for_cycle(cycle, today)

    if cycle.status_cache == status do
      %{cycle | status_cache: status}
    else
      Repo.update!(CropCycle.changeset(cycle, %{status_cache: status}))
    end
  end

  defp maybe_rotate_cycle(%Greenhouse{} = greenhouse, %CropCycle{} = cycle, rules, today) do
    if RecommendationEngine.rotation_due?(cycle, today) do
      recommendation = RecommendationEngine.build_recommendation(greenhouse, cycle, rules, today)

      next_cycle_attrs =
        recommendation_to_cycle_attrs(recommendation, greenhouse.id, cycle.plant_count)

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Repo.transaction(fn ->
        archived_cycle =
          cycle
          |> CropCycle.changeset(%{archived_at: now})
          |> Repo.update!()

        new_cycle =
          %CropCycle{}
          |> CropCycle.changeset(next_cycle_attrs)
          |> Repo.insert!()

        notification =
          insert_notification(%{
            greenhouse_id: greenhouse.id,
            crop_cycle_id: archived_cycle.id,
            kind: "auto_rotated",
            message:
              "Soil recovery ended for #{greenhouse.name}. The crop changed from #{cycle.crop_type} to #{new_cycle.crop_type} and the new cycle dates are now active.",
            notify_on: today,
            sent_at: now,
            metadata: %{
              "from_crop" => cycle.crop_type,
              "to_crop" => new_cycle.crop_type,
              "new_cycle_id" => new_cycle.id
            }
          })

        {new_cycle, notification}
      end)
      |> case do
        {:ok, {new_cycle, notification}} ->
          {new_cycle, notification}

        {:error, _step, %Ecto.Changeset{} = changeset, _changes} ->
          raise Ecto.InvalidChangesetError, action: :insert, changeset: changeset

        {:error, _step, reason, _changes} ->
          raise "failed to rotate greenhouse cycle: #{inspect(reason)}"
      end
    else
      {cycle, nil}
    end
  end

  defp upsert_recommendation(%Greenhouse{} = greenhouse, %CropCycle{} = cycle, rules, today) do
    attrs = RecommendationEngine.build_recommendation(greenhouse, cycle, rules, today)

    case Repo.get_by(OperationRecommendation, greenhouse_id: greenhouse.id) do
      nil ->
        %OperationRecommendation{}
        |> OperationRecommendation.changeset(attrs)
        |> Repo.insert!()

      recommendation ->
        recommendation
        |> OperationRecommendation.changeset(attrs)
        |> Repo.update!()
    end
  end

  defp delete_recommendation_for_greenhouse(greenhouse_id) do
    case Repo.get_by(OperationRecommendation, greenhouse_id: greenhouse_id) do
      nil -> :ok
      recommendation -> Repo.delete!(recommendation)
    end
  end

  defp recommendation_to_cycle_attrs(recommendation, greenhouse_id, plant_count) do
    %{
      greenhouse_id: greenhouse_id,
      crop_type: recommendation.next_crop,
      variety: recommendation.next_variety,
      plant_count: plant_count,
      nursery_date: recommendation.nursery_date,
      transplant_date: recommendation.transplant_date,
      harvest_start_date: recommendation.harvest_start_date,
      harvest_end_date: recommendation.harvest_end_date,
      soil_recovery_end_date: recommendation.soil_recovery_end_date,
      status_cache:
        StatusCalculator.status_for_cycle(%CropCycle{
          crop_type: recommendation.next_crop,
          harvest_start_date: recommendation.harvest_start_date,
          harvest_end_date: recommendation.harvest_end_date,
          soil_recovery_end_date: recommendation.soil_recovery_end_date
        })
    }
  end

  defp maybe_insert_recommendation_notification(
         %Greenhouse{} = greenhouse,
         %CropCycle{} = cycle,
         recommendation,
         today
       ) do
    case RecommendationEngine.notification_payload(cycle, recommendation, today) do
      nil ->
        nil

      payload ->
        insert_notification(%{
          greenhouse_id: greenhouse.id,
          crop_cycle_id: cycle.id,
          kind: payload.kind,
          message: payload.message,
          notify_on: today,
          sent_at: DateTime.utc_now() |> DateTime.truncate(:second),
          metadata: payload.metadata
        })
    end
  end

  defp insert_notification(attrs) do
    case Repo.get_by(OperationNotification,
           greenhouse_id: attrs.greenhouse_id,
           crop_cycle_id: attrs.crop_cycle_id,
           kind: attrs.kind
         ) do
      nil ->
        notification =
          %OperationNotification{}
          |> OperationNotification.changeset(attrs)
          |> Repo.insert!()
          |> Repo.preload(greenhouse: :venture)

        broadcast_notification(notification)
        notification

      notification ->
        notification
    end
  end

  defp maybe_enqueue_recommendation_refresh({:ok, _result}) do
    case Process.whereis(ChasingSun.Operations.RecommendationServer) do
      nil -> :ok
      _pid -> ChasingSun.Operations.RecommendationServer.refresh_now()
    end
  end

  defp maybe_enqueue_recommendation_refresh(_result), do: :ok

  defp broadcast_refresh(today) do
    Phoenix.PubSub.broadcast(ChasingSun.PubSub, @operations_topic, {:operations_refreshed, today})
  end

  defp broadcast_notification(notification) do
    Phoenix.PubSub.broadcast(
      ChasingSun.PubSub,
      @operations_topic,
      {:operation_notification, notification}
    )
  end
end
