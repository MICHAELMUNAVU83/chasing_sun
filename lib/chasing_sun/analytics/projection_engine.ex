defmodule ChasingSun.Analytics.ProjectionEngine do
  @moduledoc false

  def weighted_projection([], expected), do: clamp(expected || 0.0, expected)

  def weighted_projection(values, expected) do
    weighted_values =
      values
      |> Enum.take(-3)
      |> Enum.with_index(1)

    numerator =
      Enum.reduce(weighted_values, 0.0, fn {value, weight}, acc -> acc + value * weight end)

    denominator = Enum.reduce(weighted_values, 0, fn {_value, weight}, acc -> acc + weight end)

    numerator
    |> Kernel./(max(denominator, 1))
    |> clamp(expected)
  end

  defp clamp(value, expected) do
    cap = max((expected || 0.0) * 1.4, 0.0)
    value |> max(0.0) |> min(cap)
  end
end
