defmodule ChasingSun.Operations.RecommendationEngine do
  @moduledoc false

  alias ChasingSun.Operations.{CropCycle, CropPlanner, CropRule, Greenhouse, StatusCalculator}

  def build_recommendation(%Greenhouse{id: greenhouse_id}, %CropCycle{} = cycle, rules, today) do
    next_crop = CropPlanner.next_crop_recommendation(cycle.crop_type)
    next_rule = find_rule(rules, next_crop)
    next_cycle_attrs = next_cycle_attrs(cycle, next_rule, rules)
    status = StatusCalculator.status_for_cycle(cycle, today)

    %{
      greenhouse_id: greenhouse_id,
      crop_cycle_id: cycle.id,
      current_crop: cycle.crop_type,
      next_crop: next_crop,
      next_variety: Map.get(next_cycle_attrs, "variety"),
      recommendation_kind: recommendation_kind(status, next_cycle_attrs),
      note: recommendation_message(cycle, next_crop, next_cycle_attrs, today),
      nursery_date: Map.get(next_cycle_attrs, "nursery_date"),
      transplant_date: Map.get(next_cycle_attrs, "transplant_date"),
      harvest_start_date: Map.get(next_cycle_attrs, "harvest_start_date"),
      harvest_end_date: Map.get(next_cycle_attrs, "harvest_end_date"),
      soil_recovery_end_date: Map.get(next_cycle_attrs, "soil_recovery_end_date"),
      generated_on: today
    }
  end

  def next_cycle_attrs(%CropCycle{} = cycle, %CropRule{} = next_rule, rules) do
    transplant_date = cycle.soil_recovery_end_date

    attrs =
      %{
        "crop_type" => next_rule.crop_type,
        "variety" => default_variety(next_rule),
        "plant_count" => cycle.plant_count,
        "transplant_date" => transplant_date
      }
      |> maybe_put_nursery_date(next_rule, transplant_date)

    CropPlanner.normalize_cycle_attrs(attrs, rules)
  end

  def next_cycle_attrs(%CropCycle{} = cycle, nil, _rules) do
    %{
      "crop_type" => CropPlanner.next_crop_recommendation(cycle.crop_type),
      "variety" => nil,
      "plant_count" => cycle.plant_count,
      "transplant_date" => cycle.soil_recovery_end_date
    }
  end

  def nursery_window_open?(recommendation, today) do
    with %Date{} = nursery_date <- recommendation.nursery_date,
         %Date{} = transplant_date <- recommendation.transplant_date do
      Date.compare(today, nursery_date) in [:eq, :gt] and
        Date.compare(today, transplant_date) == :lt
    else
      _ -> false
    end
  end

  def without_nursery?(recommendation), do: is_nil(recommendation.nursery_date)

  def rotation_due?(%CropCycle{soil_recovery_end_date: %Date{} = soil_recovery_end_date}, today) do
    Date.compare(today, soil_recovery_end_date) in [:eq, :gt]
  end

  def rotation_due?(%CropCycle{}, _today), do: false

  def notification_payload(%CropCycle{} = cycle, recommendation, today) do
    cond do
      nursery_window_open?(recommendation, today) ->
        %{
          kind: "nursery_window_open",
          message:
            "The nursery start window has already opened for the next #{recommendation.next_crop} cycle. Transplant is planned after soil recovery.",
          metadata: %{
            "next_crop" => recommendation.next_crop,
            "transplant_date" =>
              recommendation.transplant_date && Date.to_iso8601(recommendation.transplant_date)
          }
        }

      without_nursery?(recommendation) ->
        %{
          kind: "rotate_without_nursery",
          message:
            "#{cycle.crop_type} is the current crop. Rotate to #{recommendation.next_crop} next after soil recovery. No nursery stage applies.",
          metadata: %{"next_crop" => recommendation.next_crop}
        }

      true ->
        nil
    end
  end

  def recommendation_message(%CropCycle{} = cycle, next_crop, next_cycle_attrs, today) do
    nursery_date = Map.get(next_cycle_attrs, "nursery_date")
    transplant_date = Map.get(next_cycle_attrs, "transplant_date")
    status = StatusCalculator.status_for_cycle(cycle, today)

    cond do
      is_nil(transplant_date) ->
        "#{cycle.crop_type} is active now. Set a soil recovery end date to plan the next #{next_crop} cycle."

      is_nil(nursery_date) and status == :soil_turning ->
        "Soil recovery is underway. Switch this unit to #{next_crop} on #{format_date(transplant_date)}. No nursery stage applies."

      is_nil(nursery_date) ->
        "#{cycle.crop_type} is the current crop. Rotate to #{next_crop} next after soil recovery. No nursery stage applies."

      Date.compare(today, nursery_date) in [:eq, :gt] ->
        "The nursery start window has already opened for the next #{next_crop} cycle. Transplant is planned after soil recovery on #{format_date(transplant_date)}."

      true ->
        "Start the next #{next_crop} nursery on #{format_date(nursery_date)} so transplant lands on #{format_date(transplant_date)} after soil recovery."
    end
  end

  defp recommendation_kind(:soil_turning, %{"nursery_date" => nil}), do: "soil_turning_rotation"
  defp recommendation_kind(_, %{"nursery_date" => nil}), do: "rotation_without_nursery"
  defp recommendation_kind(_, _), do: "nursery_planning"

  defp maybe_put_nursery_date(
         attrs,
         %CropRule{nursery_days: nursery_days},
         %Date{} = transplant_date
       )
       when is_integer(nursery_days) do
    Map.put(attrs, "nursery_date", Date.add(transplant_date, -nursery_days))
  end

  defp maybe_put_nursery_date(attrs, _rule, _transplant_date), do: attrs

  defp default_variety(%CropRule{} = rule) do
    rule.default_variety || List.first(rule.varieties || [])
  end

  defp find_rule(rules, crop_type) do
    Enum.find(rules, &(&1.crop_type == crop_type and &1.active))
  end

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")
  defp format_date(_date), do: "TBD"
end
