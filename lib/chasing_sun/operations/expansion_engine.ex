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

  alias ChasingSun.Operations.CropPlanner

  # Weekly weight (kg) each crop must stay at or above, farm-wide.
  @thresholds %{"Capsicum" => 500.0, "Cucumber" => 1000.0}

  # A recommended new unit is assumed to be a 16x40 / 2000-plant greenhouse.
  @new_unit_size "16x40"
  @new_unit_plant_count 2000

  # Weeks from breaking ground until the unit is ready for planting.
  @construction_days 14

  # Require at least this many weeks of actual data before deciding, and only
  # average over the most recent weeks within this window.
  @min_weeks 4
  @window_weeks 8

  @doc "Weekly weight (kg) each crop must stay at or above."
  def thresholds, do: @thresholds

  def min_weeks, do: @min_weeks

  def new_unit_size, do: @new_unit_size

  def new_unit_plant_count, do: @new_unit_plant_count

  @doc """
  Builds expansion recommendations for every crop that has fallen below its
  weekly threshold.

  `weekly_by_crop` maps a crop type to a list of `{week_ending_on, total_kg}`
  tuples (the farm-wide actual weight for that week). `used_names` is the list
  of greenhouse names already taken, so suggestions avoid them.
  """
  def recommendations(weekly_by_crop, rules, used_names, today \\ Date.utc_today()) do
    available_counties = available_counties(used_names)

    {recommendations, _remaining} =
      @thresholds
      |> Enum.sort_by(fn {crop, _threshold} -> crop end)
      |> Enum.reduce({[], available_counties}, fn {crop, threshold}, {acc, counties} ->
        case build_for_crop(crop, threshold, weekly_by_crop, rules, counties, today) do
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

  defp build_for_crop(crop, threshold, weekly_by_crop, rules, counties, today) do
    weeks =
      weekly_by_crop
      |> Map.get(crop, [])
      |> Enum.sort_by(fn {week, _total} -> week end, {:desc, Date})
      |> Enum.take(@window_weeks)

    with true <- length(weeks) >= @min_weeks,
         average <- average_weekly(weeks),
         true <- average < threshold,
         unit_yield when unit_yield > 0 <-
           CropPlanner.expected_yield(crop, @new_unit_plant_count, rules) do
      deficit = threshold - average
      units_needed = ceil(deficit / unit_yield)
      suggested_names = Enum.take(counties, units_needed)
      first_harvest_date = first_harvest_date(crop, rules, today)

      %{
        crop_type: crop,
        threshold: threshold,
        weeks_observed: length(weeks),
        average_actual: Float.round(average, 1),
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
          note(crop, threshold, average, units_needed, suggested_names, today, first_harvest_date)
      }
    else
      _ -> nil
    end
  end

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

  defp note(crop, threshold, average, units_needed, suggested_names, today, first_harvest_date) do
    names =
      case suggested_names do
        [] -> "a new unit"
        names -> Enum.join(names, ", ")
      end

    unit_word = if units_needed == 1, do: "greenhouse", else: "greenhouses"

    "#{crop} is averaging #{round(average)} kg/week of actual harvest, below the " <>
      "#{round(threshold)} kg/week target. Build #{units_needed} new #{unit_word} " <>
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
