defmodule ChasingSun.Analytics.PerformanceReport do
  @moduledoc false

  alias ChasingSun.Harvesting
  alias ChasingSun.Operations
  alias ChasingSun.Operations.CropPlanner

  @modes ~w(week month season)

  def build(filters \\ %{}) do
    base_filters = base_filters(filters)
    rules = Operations.list_crop_rules()
    greenhouses = Operations.list_greenhouses(base_filters)

    rows =
      base_filters
      |> Harvesting.list_harvest_records()
      |> Enum.map(&enrich_record(&1, rules))

    selected_greenhouse = selected_greenhouse(filters, greenhouses, rows)
    month_options = month_options(rows)
    selected_month = selected_month(filters, month_options)
    week_options = week_options(rows, selected_greenhouse)
    selected_week = selected_week(filters, week_options)
    season_options = season_options(rows, selected_greenhouse)
    selected_season_id = selected_season(filters, season_options)
    mode = selected_mode(filters)

    greenhouse_rows =
      rows
      |> rows_for_greenhouse(selected_greenhouse)
      |> rows_for_mode(mode, selected_week, selected_month, selected_season_id)

    greenhouse_report =
      aggregate_rows(
        greenhouse_rows,
        selected_greenhouse,
        period_label(mode, selected_week, selected_month, selected_season_id, season_options),
        selected_season_window(selected_season_id, season_options)
      )

    estate_rollup = estate_rollup(rows, greenhouses, selected_month)

    %{
      rows: greenhouse_rows,
      monthly: Enum.group_by(greenhouse_rows, & &1.month_label),
      summary: %{
        total_actual: greenhouse_report.actual_yield,
        total_expected: greenhouse_report.expected_yield,
        total_revenue: greenhouse_report.revenue,
        total_variance: greenhouse_report.variance
      },
      filters: %{
        venture_code: Map.get(base_filters, :venture_code, "all"),
        mode: mode,
        greenhouse_id: selected_greenhouse && selected_greenhouse.id,
        selected_week: selected_week,
        selected_month: selected_month,
        selected_season_id: selected_season_id,
        period_label:
          period_label(mode, selected_week, selected_month, selected_season_id, season_options)
      },
      greenhouse_options: greenhouse_options(greenhouses),
      month_options: month_options,
      week_options: week_options,
      season_options: season_options,
      greenhouse_report: greenhouse_report,
      estate_rollup: estate_rollup,
      estate_month_label: month_label(selected_month),
      insights:
        insights(
          greenhouse_report,
          rows,
          mode,
          selected_week,
          selected_month,
          selected_season_id,
          estate_rollup
        )
    }
  end

  defp enrich_record(record, rules) do
    crop_cycle = record.crop_cycle
    crop_type = crop_cycle && crop_cycle.crop_type
    expected = CropPlanner.expected_yield(crop_type, crop_cycle && crop_cycle.plant_count, rules)
    price_per_kg = record.price_per_kg || CropPlanner.price_for(crop_type, rules)
    revenue = record.actual_yield * price_per_kg
    variance = record.actual_yield - expected
    crop_age_weeks = crop_age_weeks(record.week_ending_on, crop_cycle && crop_cycle.harvest_start_date)

    %{
      id: record.id,
      greenhouse_id: record.greenhouse_id,
      greenhouse_name: record.greenhouse.name,
      venture_code: record.greenhouse.venture.code,
      venture_name: record.greenhouse.venture.name,
      unit_size: record.greenhouse.size,
      crop_type: crop_type,
      variety: crop_cycle && crop_cycle.variety,
      plant_count: crop_cycle && crop_cycle.plant_count,
      crop_cycle_id: crop_cycle && crop_cycle.id,
      harvest_start_date: crop_cycle && crop_cycle.harvest_start_date,
      harvest_end_date: crop_cycle && crop_cycle.harvest_end_date,
      week_ending_on: record.week_ending_on,
      month_key: month_key(record.week_ending_on),
      month_label: month_label(record.week_ending_on),
      actual_yield: record.actual_yield,
      expected_yield: expected,
      variance: variance,
      variance_pct: variance_pct(variance, expected),
      revenue: revenue,
      price_per_kg: price_per_kg,
      crop_age_weeks: crop_age_weeks,
      record: record
    }
  end

  defp selected_mode(filters) do
    filters
    |> get_value([:mode, "mode"])
    |> then(fn mode -> if mode in @modes, do: mode, else: "month" end)
  end

  defp base_filters(filters) do
    venture_code = get_value(filters, [:venture_code, "venture_code"], "all")

    case venture_code do
      nil -> %{}
      "all" -> %{}
      "" -> %{}
      code -> %{venture_code: code}
    end
  end

  defp selected_greenhouse(filters, greenhouses, rows) do
    requested_id = filters |> get_value([:greenhouse_id, "greenhouse_id"]) |> parse_int()

    by_id =
      greenhouses
      |> Enum.find(fn greenhouse -> greenhouse.id == requested_id end)

    cond do
      by_id ->
        by_id

      greenhouses != [] ->
        greenhouse_ids_with_rows =
          rows
          |> Enum.map(& &1.greenhouse_id)
          |> MapSet.new()

        Enum.find(greenhouses, &MapSet.member?(greenhouse_ids_with_rows, &1.id)) || List.first(greenhouses)

      true ->
        nil
    end
  end

  defp greenhouse_options(greenhouses) do
    Enum.map(greenhouses, fn greenhouse ->
      %{id: greenhouse.id, name: greenhouse.name, size: greenhouse.size}
    end)
  end

  defp month_options(rows) do
    rows
    |> Enum.map(& &1.month_key)
    |> Enum.uniq()
    |> Enum.sort(:desc)
    |> Enum.map(&%{value: &1, label: month_label(&1)})
  end

  defp selected_month(_filters, []), do: month_key(Date.utc_today())

  defp selected_month(filters, month_options) do
    requested = get_value(filters, [:month, "month"])
    valid_values = Enum.map(month_options, & &1.value)

    if requested in valid_values, do: requested, else: hd(valid_values)
  end

  defp week_options(rows, nil), do: week_options(rows)

  defp week_options(rows, greenhouse) do
    rows
    |> Enum.filter(&(&1.greenhouse_id == greenhouse.id))
    |> week_options()
  end

  defp week_options(rows) do
    rows
    |> Enum.map(& &1.week_ending_on)
    |> Enum.uniq()
    |> Enum.sort({:desc, Date})
    |> Enum.map(&%{value: Date.to_iso8601(&1), date: &1, label: format_date(&1)})
  end

  defp selected_week(_filters, []), do: nil

  defp selected_week(filters, week_options) do
    requested =
      filters
      |> get_value([:week, "week"])
      |> parse_date()

    valid_dates = Enum.map(week_options, & &1.date)

    if requested in valid_dates, do: requested, else: week_options |> List.first() |> Map.fetch!(:date)
  end

  defp season_options(_rows, nil), do: []

  defp season_options(rows, greenhouse) do
    grouped_options =
      rows
      |> Enum.filter(&(&1.greenhouse_id == greenhouse.id))
      |> Enum.group_by(& &1.crop_cycle_id)
      |> Enum.reject(fn {crop_cycle_id, _rows} -> is_nil(crop_cycle_id) end)
      |> Enum.map(fn {crop_cycle_id, crop_rows} ->
        first_row = Enum.max_by(crop_rows, & &1.week_ending_on, Date)

        %{
          value: Integer.to_string(crop_cycle_id),
          crop_cycle_id: crop_cycle_id,
          label:
            season_label(
              first_row.crop_type,
              first_row.harvest_start_date,
              first_row.harvest_end_date
            ),
          start_date: first_row.harvest_start_date,
          end_date: first_row.harvest_end_date
        }
      end)

    current_cycle = Operations.current_cycle(greenhouse)

    options =
      case current_cycle do
        nil ->
          grouped_options

        cycle ->
          existing = Enum.any?(grouped_options, &(&1.crop_cycle_id == cycle.id))

          if existing do
            grouped_options
          else
            [
              %{
                value: Integer.to_string(cycle.id),
                crop_cycle_id: cycle.id,
                label: season_label(cycle.crop_type, cycle.harvest_start_date, cycle.harvest_end_date),
                start_date: cycle.harvest_start_date,
                end_date: cycle.harvest_end_date
              }
              | grouped_options
            ]
          end
      end

    Enum.sort_by(options, &{&1.end_date || ~D[1900-01-01], &1.start_date || ~D[1900-01-01]}, :desc)
  end

  defp selected_season(_filters, []), do: nil

  defp selected_season(filters, season_options) do
    requested = get_value(filters, [:season_id, "season_id"])
    valid_values = Enum.map(season_options, & &1.value)

    if requested in valid_values, do: requested, else: season_options |> List.first() |> Map.fetch!(:value)
  end

  defp selected_season_window(nil, _season_options), do: {nil, nil}

  defp selected_season_window(selected_season_id, season_options) do
    case Enum.find(season_options, &(&1.value == selected_season_id)) do
      nil -> {nil, nil}
      option -> {option.start_date, option.end_date}
    end
  end

  defp rows_for_greenhouse(rows, nil), do: rows
  defp rows_for_greenhouse(rows, greenhouse), do: Enum.filter(rows, &(&1.greenhouse_id == greenhouse.id))

  defp rows_for_mode(rows, "week", %Date{} = selected_week, _selected_month, _selected_season_id) do
    Enum.filter(rows, &(&1.week_ending_on == selected_week))
  end

  defp rows_for_mode(_rows, "week", _selected_week, _selected_month, _selected_season_id), do: []

  defp rows_for_mode(rows, "month", _selected_week, selected_month, _selected_season_id) do
    Enum.filter(rows, &(&1.month_key == selected_month))
  end

  defp rows_for_mode(rows, "season", _selected_week, _selected_month, selected_season_id) do
    case parse_int(selected_season_id) do
      nil -> []
      crop_cycle_id -> Enum.filter(rows, &(&1.crop_cycle_id == crop_cycle_id))
    end
  end

  defp rows_for_mode(rows, _mode, _selected_week, _selected_month, _selected_season_id), do: rows

  defp aggregate_rows(rows, greenhouse, period_label, {season_start, season_end}) do
    latest_row = latest_row(rows)
    week_count = rows |> Enum.map(& &1.week_ending_on) |> Enum.uniq() |> length()
    actual_yield = Enum.reduce(rows, 0.0, &(&1.actual_yield + &2))
    expected_yield = Enum.reduce(rows, 0.0, &(&1.expected_yield + &2))
    revenue = Enum.reduce(rows, 0.0, &(&1.revenue + &2))
    variance = actual_yield - expected_yield

    %{
      greenhouse_id: greenhouse && greenhouse.id,
      greenhouse_name: greenhouse_name(greenhouse, latest_row),
      unit_size: greenhouse_size(greenhouse, latest_row),
      crop_type: crop_type(greenhouse, latest_row),
      plant_count: plant_count(greenhouse, latest_row),
      variety: latest_row && latest_row.variety,
      period_label: period_label,
      season_start: season_start || latest_row && latest_row.harvest_start_date,
      season_end: season_end || latest_row && latest_row.harvest_end_date,
      actual_yield: actual_yield,
      expected_yield: expected_yield,
      revenue: revenue,
      variance: variance,
      variance_pct: variance_pct(variance, expected_yield),
      harvested_weeks: week_count,
      average_per_week: if(week_count > 0, do: actual_yield / week_count, else: 0.0),
      average_crop_age_weeks: average_crop_age_weeks(rows),
      entries: aggregate_entries(rows)
    }
  end

  defp aggregate_entries(rows) do
    rows
    |> Enum.group_by(& &1.week_ending_on)
    |> Enum.map(fn {week_ending_on, week_rows} ->
      actual_yield = Enum.reduce(week_rows, 0.0, &(&1.actual_yield + &2))
      expected_yield = Enum.reduce(week_rows, 0.0, &(&1.expected_yield + &2))
      revenue = Enum.reduce(week_rows, 0.0, &(&1.revenue + &2))
      variance = actual_yield - expected_yield
      latest_row = latest_row(week_rows)

      %{
        week_ending_on: week_ending_on,
        crop_type: latest_row && latest_row.crop_type,
        actual_yield: actual_yield,
        expected_yield: expected_yield,
        revenue: revenue,
        variance: variance,
        variance_pct: variance_pct(variance, expected_yield),
        crop_age_weeks: average_crop_age_weeks(week_rows)
      }
    end)
    |> Enum.sort_by(& &1.week_ending_on, Date)
  end

  defp estate_rollup(rows, greenhouses, selected_month) do
    month_rows = Enum.filter(rows, &(&1.month_key == selected_month))

    greenhouses
    |> Enum.map(fn greenhouse ->
      greenhouse_rows = Enum.filter(month_rows, &(&1.greenhouse_id == greenhouse.id))
      aggregate_rows(greenhouse_rows, greenhouse, month_label(selected_month), {nil, nil})
    end)
    |> Enum.sort_by(&{-&1.actual_yield, &1.greenhouse_name})
  end

  defp insights(greenhouse_report, _rows, _mode, _week, _month, _season_id, _estate_rollup)
       when is_nil(greenhouse_report.greenhouse_id) do
    ["No greenhouse has been selected yet for benchmarking."]
  end

  defp insights(greenhouse_report, rows, mode, selected_week, selected_month, selected_season_id, estate_rollup) do
    peer_reports =
      rows
      |> peer_rows(mode, selected_week, selected_month, selected_season_id)
      |> Enum.group_by(&peer_group_key(&1))
      |> Map.values()
      |> Enum.map(fn peer_rows ->
        aggregate_rows(peer_rows, nil, nil, {nil, nil})
        |> Map.merge(%{
          greenhouse_name: List.first(peer_rows).greenhouse_name,
          greenhouse_id: List.first(peer_rows).greenhouse_id,
          unit_size: List.first(peer_rows).unit_size,
          crop_type: List.first(peer_rows).crop_type
        })
      end)

    comparable_peers =
      Enum.filter(peer_reports, fn peer ->
        peer.greenhouse_id != greenhouse_report.greenhouse_id and
          peer.crop_type == greenhouse_report.crop_type and
          peer.unit_size == greenhouse_report.unit_size
      end)

    estate_leader = List.first(Enum.filter(estate_rollup, &(&1.actual_yield > 0)))

    [
      peer_performance_note(greenhouse_report, comparable_peers, mode),
      crop_age_note(greenhouse_report, comparable_peers),
      estate_leader_note(estate_leader, greenhouse_report, selected_month)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp peer_rows(rows, "week", %Date{} = selected_week, _selected_month, _selected_season_id),
    do: Enum.filter(rows, &(&1.week_ending_on == selected_week))

  defp peer_rows(_rows, "week", _selected_week, _selected_month, _selected_season_id), do: []

  defp peer_rows(rows, "month", _selected_week, selected_month, _selected_season_id),
    do: Enum.filter(rows, &(&1.month_key == selected_month))

  defp peer_rows(rows, "season", _selected_week, _selected_month, _selected_season_id), do: rows
  defp peer_rows(rows, _mode, _selected_week, _selected_month, _selected_season_id), do: rows

  defp peer_group_key(row), do: {row.greenhouse_id, row.crop_cycle_id || row.month_key || row.week_ending_on}

  defp peer_performance_note(_greenhouse_report, [], _mode), do: "No fair peer group yet for this crop and unit size."

  defp peer_performance_note(greenhouse_report, comparable_peers, mode) do
    peer_average =
      comparable_peers
      |> Enum.map(& &1.average_per_week)
      |> average()

    period = period_copy(mode)
    crop_type = greenhouse_report.crop_type || "current crop"
    unit_size = greenhouse_report.unit_size || "matching"

    cond do
      peer_average == 0.0 and greenhouse_report.average_per_week > 0 ->
        "#{greenhouse_report.greenhouse_name} is producing while comparable #{crop_type} #{unit_size} units are currently at zero #{period}."

      peer_average == 0.0 ->
        "Comparable #{crop_type} #{unit_size} units do not have enough output yet for a strong benchmark #{period}."

      true ->
        delta_pct = variance_pct(greenhouse_report.average_per_week - peer_average, peer_average)

        cond do
          delta_pct >= 10 ->
            "#{greenhouse_report.greenhouse_name} is outperforming comparable #{crop_type} #{unit_size} units by #{rounded_percent(delta_pct)} #{period}."

          delta_pct <= -10 ->
            "#{greenhouse_report.greenhouse_name} is below comparable #{crop_type} #{unit_size} units by #{rounded_percent(abs(delta_pct))} #{period}."

          true ->
            "#{greenhouse_report.greenhouse_name} is broadly in line with comparable #{crop_type} #{unit_size} units #{period}."
        end
    end
  end

  defp crop_age_note(_greenhouse_report, []), do: nil

  defp crop_age_note(greenhouse_report, comparable_peers) do
    selected_age = greenhouse_report.average_crop_age_weeks
    peer_age = comparable_peers |> Enum.map(& &1.average_crop_age_weeks) |> average()

    cond do
      is_nil(selected_age) or peer_age == 0.0 ->
        nil

      selected_age - peer_age >= 2 ->
        "#{greenhouse_report.greenhouse_name} is about #{round(selected_age - peer_age)} weeks deeper into harvest than peers, so some tapering is expected."

      peer_age - selected_age >= 2 ->
        "#{greenhouse_report.greenhouse_name} is about #{round(peer_age - selected_age)} weeks earlier in harvest than peers, so output may still be ramping up."

      true ->
        "Crop age is close to peers, so this comparison is on a like-for-like harvest stage."
    end
  end

  defp estate_leader_note(nil, _greenhouse_report, _selected_month), do: nil

  defp estate_leader_note(estate_leader, greenhouse_report, selected_month) do
    cond do
      estate_leader.greenhouse_id == greenhouse_report.greenhouse_id ->
        "#{greenhouse_report.greenhouse_name} is currently leading the estate rollup for #{month_label(selected_month)}."

      true ->
        "#{estate_leader.greenhouse_name} is leading the estate rollup for #{month_label(selected_month)} at #{format_quantity(estate_leader.actual_yield)}."
    end
  end

  defp greenhouse_name(%{name: name}, _latest_row), do: name
  defp greenhouse_name(_greenhouse, latest_row), do: latest_row && latest_row.greenhouse_name

  defp greenhouse_size(%{size: size}, _latest_row), do: size
  defp greenhouse_size(_greenhouse, latest_row), do: latest_row && latest_row.unit_size

  defp crop_type(greenhouse, latest_row) do
    cond do
      latest_row && latest_row.crop_type ->
        latest_row.crop_type

      greenhouse ->
        case Operations.current_cycle(greenhouse) do
          nil -> nil
          cycle -> cycle.crop_type
        end

      true ->
        nil
    end
  end

  defp plant_count(greenhouse, latest_row) do
    cond do
      latest_row && latest_row.plant_count ->
        latest_row.plant_count

      greenhouse ->
        case Operations.current_cycle(greenhouse) do
          nil -> nil
          cycle -> cycle.plant_count
        end

      true ->
        nil
    end
  end

  defp latest_row([]), do: nil
  defp latest_row(rows), do: Enum.max_by(rows, & &1.week_ending_on, Date)

  defp average_crop_age_weeks(rows) do
    rows
    |> Enum.map(& &1.crop_age_weeks)
    |> Enum.reject(&is_nil/1)
    |> average_or_nil()
  end

  defp average([]), do: 0.0
  defp average(values), do: Enum.sum(values) / length(values)

  defp average_or_nil([]), do: nil
  defp average_or_nil(values), do: average(values)

  defp crop_age_weeks(_week_ending_on, nil), do: nil

  defp crop_age_weeks(%Date{} = week_ending_on, %Date{} = harvest_start_date) do
    max(Date.diff(week_ending_on, harvest_start_date), 0) / 7
  end

  defp period_label("week", %Date{} = selected_week, _selected_month, _selected_season_id, _season_options),
    do: format_date(selected_week)

  defp period_label("month", _selected_week, selected_month, _selected_season_id, _season_options),
    do: month_label(selected_month)

  defp period_label("season", _selected_week, _selected_month, selected_season_id, season_options) do
    case Enum.find(season_options, &(&1.value == selected_season_id)) do
      nil -> "Selected season"
      option -> option.label
    end
  end

  defp period_label(_mode, _selected_week, _selected_month, _selected_season_id, _season_options),
    do: "Selected period"

  defp season_label(crop_type, harvest_start_date, harvest_end_date) do
    crop = crop_type || "Crop"
    "#{crop} season · #{format_date(harvest_start_date)} to #{format_date(harvest_end_date)}"
  end

  defp month_key(%Date{} = date), do: Calendar.strftime(date, "%Y-%m")
  defp month_key(_date), do: nil

  defp month_label(%Date{} = date), do: Calendar.strftime(date, "%b %Y")

  defp month_label(<<_year::binary-size(4), "-", _month::binary-size(2)>> = value) do
    case Date.from_iso8601(value <> "-01") do
      {:ok, date} -> Calendar.strftime(date, "%b %Y")
      _ -> value
    end
  end

  defp month_label(value) when is_binary(value), do: value
  defp month_label(_value), do: "Unknown month"

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")
  defp format_date(_date), do: "TBD"

  defp format_quantity(value), do: ChasingSunWeb.FormatHelpers.format_number(value, decimals: 1)

  defp variance_pct(_variance, 0.0), do: 0.0
  defp variance_pct(variance, expected), do: variance / expected * 100.0

  defp rounded_percent(value), do: "#{Float.round(value, 1)}%"

  defp period_copy("week"), do: "this week"
  defp period_copy("month"), do: "this month"
  defp period_copy("season"), do: "this season"
  defp period_copy(_mode), do: "in this view"

  defp parse_date(%Date{} = date), do: date

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _error -> nil
    end
  end

  defp parse_date(_value), do: nil

  defp parse_int(nil), do: nil
  defp parse_int(value) when is_integer(value), do: value

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} -> parsed
      _ -> nil
    end
  end

  defp parse_int(_value), do: nil

  defp get_value(data, keys, default \\ nil) do
    Enum.find_value(keys, default, &Map.get(data, &1))
  end
end
