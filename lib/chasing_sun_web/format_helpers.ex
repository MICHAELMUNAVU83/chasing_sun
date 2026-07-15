defmodule ChasingSunWeb.FormatHelpers do
  @moduledoc false

  def display_value(value) when is_number(value), do: format_number(value)
  def display_value(value), do: value

  def format_currency(value, opts \\ [])

  def format_currency(%Decimal{} = value, opts) do
    decimals = Keyword.get(opts, :decimals, 2)
    "KES " <> format_number(Decimal.to_float(value), decimals: decimals)
  end

  def format_currency(value, opts) when is_number(value) do
    decimals = Keyword.get(opts, :decimals, default_decimals(value))
    "KES " <> format_number(value, decimals: decimals)
  end

  def format_currency(_value, opts), do: "KES " <> format_number(0, opts)

  def format_number(value, opts \\ [])

  def format_number(%Decimal{} = value, opts) do
    decimals = Keyword.get(opts, :decimals, 2)
    format_number(Decimal.to_float(value), decimals: decimals)
  end

  def format_number(value, opts) when is_integer(value) do
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

  @doc """
  Formats a number exactly as stored, without rounding to a fixed number of
  decimals. Thousands are grouped and a trailing ".0" on whole numbers is dropped.
  """
  def format_exact(value) when is_integer(value), do: value |> Integer.to_string() |> add_commas()

  def format_exact(value) when is_float(value) do
    value
    |> Float.to_string()
    |> String.replace_suffix(".0", "")
    |> add_commas()
  end

  def format_exact(_value), do: "0"

  @doc """
  Like `format_currency/2` but preserves the value exactly as stored (no rounding).
  """
  def format_currency_exact(value) when is_number(value), do: "KES " <> format_exact(value)
  def format_currency_exact(_value), do: "KES 0"

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
