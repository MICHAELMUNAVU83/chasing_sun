defmodule ChasingSun.Operations.CropPlanner do
  @moduledoc false

  alias ChasingSun.Operations.{CropCycle, CropRule, StatusCalculator}

  @soil_recovery_days 30

  def normalize_cycle_attrs(attrs, rules) do
    crop_type = fetch_string(attrs, ["crop_type", :crop_type])
    rule = find_rule(rules, crop_type)

    attrs
    |> maybe_put(
      "variety",
      blank_to_nil(fetch_string(attrs, ["variety", :variety])) ||
        rule_default(rule, :default_variety)
    )
    |> maybe_put("nursery_date", fetch_date(attrs, ["nursery_date", :nursery_date]))
    |> maybe_put("transplant_date", derive_transplant_date(attrs, rule))
    |> maybe_put("harvest_start_date", derive_harvest_start_date(attrs, rule))
    |> maybe_put("harvest_end_date", derive_harvest_end_date(attrs, rule))
    |> maybe_put("soil_recovery_end_date", derive_soil_recovery_end_date(attrs))
    |> maybe_put("status_cache", derive_status(attrs))
  end

  def expected_yield(%CropCycle{} = cycle, rules),
    do: expected_yield(cycle.crop_type, cycle.plant_count, rules)

  def expected_yield(crop_type, plant_count, rules) do
    case find_rule(rules, crop_type) do
      nil ->
        0.0

      %CropRule{flat_expected_yield: flat} when is_number(flat) and flat > 0 ->
        flat

      %CropRule{} = rule when is_integer(plant_count) and plant_count >= 1_500 ->
        rule.expected_yield_2000 || 0.0

      %CropRule{} = rule ->
        rule.expected_yield_1000 || 0.0
    end
  end

  def price_for(crop_type, rules) do
    case find_rule(rules, crop_type) do
      %CropRule{price_per_unit: price} when is_number(price) -> price
      _ -> 0.0
    end
  end

  def next_crop_recommendation("Cucumber"), do: "Capsicum"
  def next_crop_recommendation("Local Cucumber"), do: "Capsicum"
  def next_crop_recommendation("Capsicum"), do: "Cucumber"
  def next_crop_recommendation(_), do: "Capsicum"

  def saturdays(start_date \\ Date.utc_today(), count \\ 8) do
    first = next_saturday(start_date)
    Enum.map(0..(count - 1), &Date.add(first, &1 * 7))
  end

  def next_saturday(date \\ Date.utc_today()) do
    days_until = rem(6 - Date.day_of_week(date, :monday) + 7, 7)
    offset = if days_until == 0, do: 7, else: days_until
    Date.add(date, offset)
  end

  def status(%CropCycle{} = cycle, today \\ Date.utc_today()),
    do: StatusCalculator.status_for_cycle(cycle, today)

  def soil_recovery_days, do: @soil_recovery_days

  defp derive_transplant_date(attrs, %CropRule{nursery_days: nursery_days})
       when is_integer(nursery_days) do
    transplant_date = fetch_date(attrs, ["transplant_date", :transplant_date])

    case transplant_date || fetch_date(attrs, ["nursery_date", :nursery_date]) do
      %Date{} when not is_nil(transplant_date) ->
        transplant_date

      %Date{} = nursery ->
        Date.add(nursery, nursery_days)

      _ ->
        nil
    end
  end

  defp derive_transplant_date(attrs, _rule),
    do: fetch_date(attrs, ["transplant_date", :transplant_date])

  defp derive_harvest_start_date(attrs, %CropRule{days_to_harvest: days}) when is_integer(days) do
    harvest_start_date = fetch_date(attrs, ["harvest_start_date", :harvest_start_date])

    case harvest_start_date || fetch_date(attrs, ["transplant_date", :transplant_date]) do
      %Date{} when not is_nil(harvest_start_date) ->
        harvest_start_date

      %Date{} = transplant ->
        Date.add(transplant, days)

      _ ->
        nil
    end
  end

  defp derive_harvest_start_date(attrs, _rule),
    do: fetch_date(attrs, ["harvest_start_date", :harvest_start_date])

  defp derive_harvest_end_date(attrs, %CropRule{harvest_period_days: days})
       when is_integer(days) do
    harvest_end_date = fetch_date(attrs, ["harvest_end_date", :harvest_end_date])

    case harvest_end_date || fetch_date(attrs, ["harvest_start_date", :harvest_start_date]) do
      %Date{} when not is_nil(harvest_end_date) ->
        harvest_end_date

      %Date{} = harvest_start ->
        Date.add(harvest_start, days)

      _ ->
        nil
    end
  end

  defp derive_harvest_end_date(attrs, _rule),
    do: fetch_date(attrs, ["harvest_end_date", :harvest_end_date])

  defp derive_soil_recovery_end_date(attrs) do
    soil_recovery_end_date =
      fetch_date(attrs, ["soil_recovery_end_date", :soil_recovery_end_date])

    case soil_recovery_end_date || fetch_date(attrs, ["harvest_end_date", :harvest_end_date]) do
      %Date{} when not is_nil(soil_recovery_end_date) ->
        soil_recovery_end_date

      %Date{} = harvest_end ->
        Date.add(harvest_end, @soil_recovery_days)

      _ ->
        nil
    end
  end

  defp derive_status(attrs) do
    attrs
    |> Map.new(fn {key, value} -> {to_string(key), value} end)
    |> then(fn params ->
      %CropCycle{}
      |> CropCycle.changeset(%{
        greenhouse_id: params["greenhouse_id"] || 0,
        crop_type: params["crop_type"] || "Pending",
        harvest_start_date: params["harvest_start_date"],
        harvest_end_date: params["harvest_end_date"],
        soil_recovery_end_date: params["soil_recovery_end_date"]
      })
      |> Ecto.Changeset.apply_changes()
      |> StatusCalculator.status_for_cycle()
      |> Atom.to_string()
    end)
  end

  defp rule_default(nil, _field), do: nil
  defp rule_default(rule, field), do: Map.get(rule, field)

  defp find_rule(_rules, nil), do: nil

  defp find_rule(rules, crop_type) do
    Enum.find(rules, fn rule -> rule.crop_type == crop_type end)
  end

  defp fetch_string(attrs, keys) do
    keys
    |> Enum.find_value(fn key ->
      case Map.get(attrs, key) do
        value when is_binary(value) -> String.trim(value)
        value -> value
      end
    end)
    |> blank_to_nil()
  end

  defp fetch_date(attrs, keys) do
    Enum.find_value(keys, fn key ->
      case Map.get(attrs, key) do
        %Date{} = value -> value
        value when is_binary(value) and value != "" -> Date.from_iso8601!(value)
        _ -> nil
      end
    end)
  end

  defp maybe_put(attrs, _key, nil), do: attrs
  defp maybe_put(attrs, key, value), do: Map.put(attrs, key, value)

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
