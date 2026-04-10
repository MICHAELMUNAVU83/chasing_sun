defmodule ChasingSun.Analytics do
  @moduledoc false

  alias ChasingSun.Analytics.{ForecastEngine, ProjectionEngine}
  alias ChasingSun.Harvesting
  alias ChasingSun.Operations
  alias ChasingSun.Operations.CropPlanner

  def dashboard(filters \\ %{}) do
    Operations.dashboard_snapshot(filters)
  end

  def performance_report(filters \\ %{}) do
    rules = Operations.list_crop_rules()

    rows =
      filters
      |> Harvesting.list_harvest_records()
      |> Enum.map(fn record ->
        crop_type = record.crop_cycle && record.crop_cycle.crop_type

        expected =
          CropPlanner.expected_yield(
            crop_type,
            record.crop_cycle && record.crop_cycle.plant_count,
            rules
          )

        revenue = record.actual_yield * CropPlanner.price_for(crop_type, rules)
        variance = record.actual_yield - expected

        %{
          id: record.id,
          month: Calendar.strftime(record.week_ending_on, "%b %Y"),
          greenhouse_name: record.greenhouse.name,
          venture_code: record.greenhouse.venture.code,
          crop_type: crop_type,
          week_ending_on: record.week_ending_on,
          actual_yield: record.actual_yield,
          expected_yield: expected,
          variance: variance,
          variance_pct: variance_pct(variance, expected),
          revenue: revenue,
          record: record
        }
      end)

    %{
      rows: rows,
      monthly: Enum.group_by(rows, & &1.month),
      summary: %{
        total_actual: Enum.reduce(rows, 0.0, &(&1.actual_yield + &2)),
        total_expected: Enum.reduce(rows, 0.0, &(&1.expected_yield + &2)),
        total_revenue: Enum.reduce(rows, 0.0, &(&1.revenue + &2))
      }
    }
  end

  def next_saturday_projection(filters \\ %{}) do
    rules = Operations.list_crop_rules()
    date = CropPlanner.next_saturday(Date.utc_today())

    Operations.list_greenhouses(filters)
    |> Enum.filter(fn greenhouse ->
      case Operations.current_cycle(greenhouse) do
        nil -> false
        cycle -> CropPlanner.status(cycle, date) == :harvesting
      end
    end)
    |> Enum.map(fn greenhouse ->
      cycle = Operations.current_cycle(greenhouse)
      expected = CropPlanner.expected_yield(cycle, rules)

      projected =
        greenhouse.harvest_records
        |> Enum.sort_by(& &1.week_ending_on, Date)
        |> Enum.map(& &1.actual_yield)
        |> ProjectionEngine.weighted_projection(expected)

      %{
        greenhouse_name: greenhouse.name,
        crop_type: cycle.crop_type,
        expected: expected,
        projected: projected,
        week_ending_on: date
      }
    end)
  end

  def forecast(filters \\ %{}, weeks \\ 8) do
    greenhouses = Operations.list_greenhouses(filters)
    rules = Operations.list_crop_rules()

    %{
      weeks: ForecastEngine.weekly_forecast(greenhouses, rules, weeks),
      recommendations: recommendations(greenhouses),
      projection: next_saturday_projection(filters)
    }
  end

  defp recommendations(greenhouses) do
    greenhouses
    |> Enum.map(fn greenhouse ->
      case Operations.current_cycle(greenhouse) do
        nil ->
          nil

        cycle ->
          %{
            greenhouse_name: greenhouse.name,
            current_crop: cycle.crop_type,
            next_crop: CropPlanner.next_crop_recommendation(cycle.crop_type),
            harvest_end_date: cycle.harvest_end_date
          }
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(&{&1.harvest_end_date || ~D[9999-12-31], &1.greenhouse_name}, &<=/2)
    |> Enum.take(6)
  end

  defp variance_pct(_variance, 0.0), do: 0.0
  defp variance_pct(variance, expected), do: variance / expected * 100.0
end
