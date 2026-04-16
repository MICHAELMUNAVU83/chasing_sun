defmodule ChasingSun.Analytics.ForecastEngine do
  @moduledoc false

  alias ChasingSun.Operations
  alias ChasingSun.Operations.CropPlanner

  def weekly_forecast(greenhouses, rules, weeks \\ 8) do
    CropPlanner.saturdays(Date.utc_today(), weeks)
    |> Enum.map(fn saturday ->
      active_units =
        Enum.filter(greenhouses, fn greenhouse ->
          case Operations.current_cycle(greenhouse) do
            nil -> false
            cycle -> CropPlanner.status(cycle, saturday) == :harvesting
          end
        end)

      expected_output =
        Enum.reduce(active_units, 0.0, fn greenhouse, acc ->
          acc + CropPlanner.expected_yield(Operations.current_cycle(greenhouse), rules)
        end)

      %{
        week_ending_on: saturday,
        active_units: length(active_units),
        expected_output: expected_output,
        greenhouses: active_units
      }
    end)
  end
end
