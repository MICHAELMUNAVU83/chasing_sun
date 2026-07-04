defmodule ChasingSun.Operations.ExpansionEngine do
  @moduledoc """
  Decides when a new greenhouse should be constructed to keep weekly produce
  above its target, based on the *actual* weights harvested per week.

  The engine only ever looks at recorded harvest weights (never forecasted or
  expected yields) and needs at least `min_weeks/0` weeks of data for a crop
  before it will make a call. When the rolling weekly average drops below the
  crop's threshold it sizes the expansion (how many new units close the gap),
  works out the construction and first-harvest dates, and suggests names taken
  from Kenyan counties that are not already in use.
  """

  alias ChasingSun.Operations.{CropCycle, CropPlanner, CropRule, Greenhouse}

  @continuous_harvest_crop "Local Cucumber"

  # Weekly weight (kg) each crop must stay at or above, farm-wide.
  @thresholds %{"Capsicum" => 500.0, "Cucumber" => 1000.0, "Local Cucumber" => 500.0}

  # A recommended new unit is assumed to be a 16x40 / 2000-plant greenhouse.
  @new_unit_size "16x40"
  @new_unit_plant_count 2000

  # Weeks from breaking ground until the unit is ready for planting.
  @construction_days 14

  # Require at least this many weeks of actual data before deciding, and only
  # average over the most recent weeks within this window.
  @min_weeks 4
  @window_weeks 8
  @near_harvest_lookahead_days 35

  @doc "Weekly weight (kg) each crop must stay at or above."
  def thresholds, do: @thresholds

  def min_weeks, do: @min_weeks

  def new_unit_size, do: @new_unit_size

  def new_unit_plant_count, do: @new_unit_plant_count

  def near_harvest_lookahead_days, do: @near_harvest_lookahead_days

  def construction_days, do: @construction_days

  @doc """
  The alert lead time needed to bring a replacement 16x40 unit into harvest.

  This is intentionally based on crop rules instead of the short near-harvest
  forecast horizon. For continuity planning, the prompt must fire before there
  is no longer enough time to build, raise seedlings where needed, and reach the
  next first harvest.
  """
  def continuous_harvest_crop, do: @continuous_harvest_crop

  def continuous_harvest_lead_days(rules, crop_type \\ nil) do
    rules
    |> Enum.filter(&continuous_harvest_crop?(&1, crop_type))
    |> Enum.map(fn rule ->
      @construction_days + non_negative(rule.nursery_days) + non_negative(rule.days_to_harvest)
    end)
    |> Enum.max(fn -> @construction_days end)
  end

  @doc """
  Returns the latest Chasing Sun 16x40 cycle at risk, or nil when the pipeline
  already has a replacement whose harvest begins before the current pipeline
  closes.
  """
  def continuous_harvest_risk(
        active_cycles,
        rules,
        today,
        crop_type \\ @continuous_harvest_crop
      ) do
    lead_days = continuous_harvest_lead_days(rules, crop_type)

    active_cycles
    |> latest_harvest_cycle(crop_type)
    |> case do
      nil ->
        first_active_cycle(active_cycles)

      {latest_greenhouse, latest_cycle} = latest ->
        cutoff_date = Date.add(today, lead_days)

        cond do
          Date.compare(latest_cycle.harvest_end_date, cutoff_date) == :gt ->
            nil

          replacement_harvest_ready?(active_cycles, latest, today, crop_type) ->
            nil

          true ->
            %{
              greenhouse: latest_greenhouse,
              cycle: latest_cycle,
              lead_days: lead_days,
              replacement_required_by: latest_cycle.harvest_end_date
            }
        end
    end
  end

  @doc """
  Builds expansion recommendations for every crop that has fallen below its
  weekly threshold.

  `weekly_by_crop` maps a crop type to a list of `{week_ending_on, total_kg}`
  tuples (the farm-wide actual weight for that week). `used_names` is the list
  of greenhouse names already taken, so suggestions avoid them.
  """
  def recommendations(weekly_by_crop, rules, used_names) do
    recommendations(weekly_by_crop, rules, used_names, %{}, Date.utc_today())
  end

  def recommendations(weekly_by_crop, rules, used_names, today) when is_struct(today, Date) do
    recommendations(weekly_by_crop, rules, used_names, %{}, today)
  end

  def recommendations(weekly_by_crop, rules, used_names, upcoming_by_crop, today) do
    available_counties = available_counties(used_names)

    {recommendations, _remaining} =
      @thresholds
      |> Enum.sort_by(fn {crop, _threshold} -> crop end)
      |> Enum.reduce({[], available_counties}, fn {crop, threshold}, {acc, counties} ->
        case build_for_crop(
               crop,
               threshold,
               weekly_by_crop,
               rules,
               counties,
               upcoming_by_crop,
               today
             ) do
          nil ->
            {acc, counties}

          recommendation ->
            {[recommendation | acc], Enum.drop(counties, length(recommendation.suggested_names))}
        end
      end)

    Enum.reverse(recommendations)
  end

  @doc "All 47 Kenyan counties, in order, used as the pool of suggested names."
  def kenyan_counties do
    [
      "Mombasa",
      "Kwale",
      "Kilifi",
      "Tana River",
      "Lamu",
      "Taita-Taveta",
      "Garissa",
      "Wajir",
      "Mandera",
      "Marsabit",
      "Isiolo",
      "Meru",
      "Tharaka-Nithi",
      "Embu",
      "Kitui",
      "Machakos",
      "Makueni",
      "Nyandarua",
      "Nyeri",
      "Kirinyaga",
      "Murang'a",
      "Kiambu",
      "Turkana",
      "West Pokot",
      "Samburu",
      "Trans-Nzoia",
      "Uasin Gishu",
      "Elgeyo-Marakwet",
      "Nandi",
      "Baringo",
      "Laikipia",
      "Nakuru",
      "Narok",
      "Kajiado",
      "Kericho",
      "Bomet",
      "Kakamega",
      "Vihiga",
      "Bungoma",
      "Busia",
      "Siaya",
      "Kisumu",
      "Homa Bay",
      "Migori",
      "Kisii",
      "Nyamira",
      "Nairobi"
    ]
  end

  @doc "Kenyan counties not yet used as greenhouse names."
  def available_counties(used_names) do
    used = MapSet.new(used_names, &normalize_name/1)

    Enum.reject(kenyan_counties(), fn county ->
      MapSet.member?(used, normalize_name(county))
    end)
  end

  defp build_for_crop(crop, threshold, weekly_by_crop, rules, counties, upcoming_by_crop, today) do
    weeks =
      weekly_by_crop
      |> Map.get(crop, [])
      |> Enum.sort_by(fn {week, _total} -> week end, {:desc, Date})
      |> Enum.take(@window_weeks)

    upcoming_weekly_yield = Map.get(upcoming_by_crop, crop, 0.0)

    with true <- length(weeks) >= @min_weeks,
         average <- average_weekly(weeks),
         adjusted_average <- average + upcoming_weekly_yield,
         true <- adjusted_average < threshold,
         unit_yield when unit_yield > 0 <-
           CropPlanner.expected_yield(crop, @new_unit_plant_count, rules) do
      deficit = threshold - adjusted_average
      units_needed = ceil(deficit / unit_yield)
      suggested_names = Enum.take(counties, units_needed)
      first_harvest_date = first_harvest_date(crop, rules, today)

      %{
        crop_type: crop,
        threshold: threshold,
        weeks_observed: length(weeks),
        average_actual: Float.round(average, 1),
        upcoming_weekly_yield: Float.round(upcoming_weekly_yield, 1),
        deficit: Float.round(deficit, 1),
        unit_size: @new_unit_size,
        unit_plant_count: @new_unit_plant_count,
        unit_expected_yield: unit_yield,
        units_needed: units_needed,
        suggested_names: suggested_names,
        construction_start_date: today,
        construction_days: @construction_days,
        first_harvest_date: first_harvest_date,
        generated_on: today,
        note:
          note(
            crop,
            threshold,
            average,
            upcoming_weekly_yield,
            units_needed,
            suggested_names,
            today,
            first_harvest_date
          )
      }
    else
      _ -> nil
    end
  end

  defp latest_harvest_cycle(active_cycles, crop_type) do
    active_cycles
    |> Enum.filter(fn {_greenhouse, cycle} ->
      cycle.crop_type == crop_type and match?(%Date{}, cycle.harvest_end_date)
    end)
    |> Enum.sort_by(fn {_greenhouse, cycle} -> cycle.harvest_end_date end, {:desc, Date})
    |> List.first()
  end

  defp first_active_cycle(active_cycles) do
    case List.first(active_cycles) do
      {%Greenhouse{} = greenhouse, %CropCycle{} = cycle} ->
        %{
          greenhouse: greenhouse,
          cycle: cycle,
          lead_days: nil,
          replacement_required_by: nil
        }

      _ ->
        nil
    end
  end

  defp replacement_harvest_ready?(
         active_cycles,
         {_latest_greenhouse,
          %CropCycle{id: latest_cycle_id, harvest_end_date: harvest_end_date}},
         today,
         crop_type
       ) do
    Enum.any?(active_cycles, fn {_greenhouse, cycle} ->
      cycle.id != latest_cycle_id and
        cycle.crop_type == crop_type and
        future_harvest_start_by?(cycle, today, harvest_end_date)
    end)
  end

  defp future_harvest_start_by?(
         %CropCycle{harvest_start_date: %Date{} = harvest_start_date},
         today,
         %Date{} = required_by
       ) do
    Date.compare(harvest_start_date, today) == :gt and
      Date.compare(harvest_start_date, required_by) != :gt
  end

  defp future_harvest_start_by?(_cycle, _today, _required_by), do: false

  defp continuous_harvest_crop?(%CropRule{crop_type: rule_crop_type, active: active}, nil) do
    active != false and Map.has_key?(@thresholds, rule_crop_type)
  end

  defp continuous_harvest_crop?(%CropRule{crop_type: rule_crop_type, active: active}, crop_type) do
    active != false and rule_crop_type == crop_type
  end

  defp continuous_harvest_crop?(_rule, _crop_type), do: false

  defp non_negative(value) when is_integer(value) and value > 0, do: value
  defp non_negative(_value), do: 0

  defp average_weekly(weeks) do
    total = Enum.reduce(weeks, 0.0, fn {_week, weight}, acc -> acc + (weight || 0.0) end)
    total / length(weeks)
  end

  # Construction must finish before transplanting; the seedlings then go through
  # the nursery (if any) and the days-to-harvest before the first pick. We chain
  # these sequentially so the date is a safe (latest) estimate.
  defp first_harvest_date(crop, rules, today) do
    rule = Enum.find(rules, &(&1.crop_type == crop))
    nursery_days = (rule && rule.nursery_days) || 0
    days_to_harvest = (rule && rule.days_to_harvest) || 0

    Date.add(today, @construction_days + nursery_days + days_to_harvest)
  end

  defp note(
         crop,
         threshold,
         average,
         upcoming_weekly_yield,
         units_needed,
         suggested_names,
         today,
         first_harvest_date
       ) do
    names =
      case suggested_names do
        [] -> "a new unit"
        names -> Enum.join(names, ", ")
      end

    unit_word = if units_needed == 1, do: "greenhouse", else: "greenhouses"

    future_context =
      if upcoming_weekly_yield > 0 do
        " About #{round(upcoming_weekly_yield)} kg/week is already expected from units nearing harvest, but the crop still sits below target."
      else
        ""
      end

    "#{crop} is averaging #{round(average)} kg/week of actual harvest, below the " <>
      "#{round(threshold)} kg/week target.#{future_context} Build #{units_needed} new #{unit_word} " <>
      "(suggested: #{names}). Start construction by #{format_date(today)} so the first " <>
      "harvest lands around #{format_date(first_harvest_date)} and weekly output recovers " <>
      "above target."
  end

  defp normalize_name(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]/u, "")
  end

  defp normalize_name(_name), do: ""

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")
  defp format_date(_date), do: "TBD"
end
