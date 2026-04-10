defmodule ChasingSunWeb.FormatHelpers do
  @moduledoc false

  def display_value(value) when is_number(value), do: format_number(value)
  def display_value(value), do: value

  def format_currency(value, opts \\ []) when is_number(value) do
    decimals = Keyword.get(opts, :decimals, default_decimals(value))
    "KES " <> format_number(value, decimals: decimals)
  end

  def format_currency(_value, opts), do: "KES " <> format_number(0, opts)

  def format_number(value, opts \\ []) when is_integer(value) do
    decimals = Keyword.get(opts, :decimals, 0)
    value
    |> decimal_string(decimals)
    |> add_commas()
  end

  def format_number(value, opts) when is_float(value) do
    decimals = Keyword.get(opts, :decimals, default_decimals(value))

    value
    |> decimal_string(decimals)
    |> add_commas()
  end

  def format_number(_value, opts), do: format_number(0, opts)

  defp default_decimals(value) when is_integer(value), do: 0
  defp default_decimals(_value), do: 1

  defp decimal_string(value, 0), do: Integer.to_string(round(value))

  defp decimal_string(value, decimals) do
    :erlang.float_to_binary(value * 1.0, decimals: decimals)
  end

  defp add_commas(value) do
    {sign, unsigned} = split_sign(value)
    [whole | fraction] = String.split(unsigned, ".", parts: 2)

    grouped =
      whole
      |> String.graphemes()
      |> Enum.reverse()
      |> Enum.chunk_every(3)
      |> Enum.map(&(Enum.reverse(&1) |> Enum.join()))
      |> Enum.reverse()
      |> Enum.join(",")

    sign <> grouped <> fraction_suffix(fraction)
  end

  defp split_sign("-" <> rest), do: {"-", rest}
  defp split_sign(value), do: {"", value}

  defp fraction_suffix([decimal]), do: "." <> decimal
  defp fraction_suffix(_), do: ""
end