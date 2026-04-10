defmodule ChasingSun.Operations.StatusCalculator do
  @moduledoc false

  alias ChasingSun.Operations.CropCycle

  def status_for_cycle(%CropCycle{} = cycle, today \\ Date.utc_today()) do
    cond do
      between?(today, cycle.harvest_start_date, cycle.harvest_end_date) -> :harvesting
      after_or_equal?(today, next_day(cycle.harvest_end_date)) and on_or_before?(today, cycle.soil_recovery_end_date) -> :soil_turning
      true -> :waiting
    end
  end

  defp between?(_today, nil, nil), do: false
  defp between?(today, from, to), do: on_or_after?(today, from) and on_or_before?(today, to)

  defp next_day(nil), do: nil
  defp next_day(date), do: Date.add(date, 1)

  defp on_or_after?(_today, nil), do: false
  defp on_or_after?(today, date), do: Date.compare(today, date) in [:gt, :eq]

  defp after_or_equal?(today, date), do: on_or_after?(today, date)

  defp on_or_before?(_today, nil), do: false
  defp on_or_before?(today, date), do: Date.compare(today, date) in [:lt, :eq]
end