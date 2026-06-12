defmodule ChasingSun.Analytics do
  @moduledoc false

  alias ChasingSun.Analytics.{ForecastEngine, PerformanceReport, ProjectionEngine}
  alias ChasingSun.Operations
  alias ChasingSun.Operations.CropPlanner

  def dashboard(filters \\ %{}) do
    Operations.dashboard_snapshot(filters)
  end

  def performance_report(filters \\ %{}), do: PerformanceReport.build(filters)

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

    %{
      weeks: ForecastEngine.weekly_forecast(greenhouses, Operations.list_crop_rules(), weeks),
      recommendations: Operations.list_operation_recommendations(filters),
      notifications: Operations.recent_operation_notifications(8, filters),
      projection: next_saturday_projection(filters)
    }
  end
end
