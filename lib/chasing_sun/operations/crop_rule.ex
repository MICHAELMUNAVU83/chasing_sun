defmodule ChasingSun.Operations.CropRule do
  use Ecto.Schema
  import Ecto.Changeset

  schema "crop_rules" do
    field :crop_type, :string
    field :nursery_days, :integer
    field :days_to_harvest, :integer
    field :harvest_period_days, :integer
    field :default_variety, :string
    field :varieties, {:array, :string}, default: []
    field :varieties_text, :string, virtual: true
    field :forced_size, :string
    field :expected_yield_1000, :float
    field :expected_yield_2000, :float
    field :flat_expected_yield, :float
    field :price_per_unit, :float
    field :active, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  def changeset(crop_rule, attrs) do
    crop_rule
    |> cast(attrs, [
      :crop_type,
      :nursery_days,
      :days_to_harvest,
      :harvest_period_days,
      :default_variety,
      :varieties,
      :varieties_text,
      :forced_size,
      :expected_yield_1000,
      :expected_yield_2000,
      :flat_expected_yield,
      :price_per_unit,
      :active
    ])
    |> normalize_varieties()
    |> ensure_default_variety()
    |> validate_required([:crop_type, :price_per_unit])
    |> unique_constraint(:crop_type)
  end

  def varieties_to_text(varieties) when is_list(varieties), do: Enum.join(varieties, "\n")
  def varieties_to_text(_), do: ""

  defp normalize_varieties(changeset) do
    varieties =
      cond do
        changed_text = get_change(changeset, :varieties_text) ->
          parse_varieties(changed_text)

        changed_varieties = get_change(changeset, :varieties) ->
          normalize_variety_list(changed_varieties)

        true ->
          normalize_variety_list(get_field(changeset, :varieties) || [])
      end

    changeset
    |> put_change(:varieties, varieties)
    |> put_change(:varieties_text, varieties_to_text(varieties))
  end

  defp ensure_default_variety(changeset) do
    default_variety =
      changeset
      |> get_field(:default_variety)
      |> normalize_variety_name()

    varieties =
      changeset
      |> get_field(:varieties, [])
      |> normalize_variety_list()
      |> maybe_add_default(default_variety)

    changeset
    |> put_change(:varieties, varieties)
    |> put_change(:varieties_text, varieties_to_text(varieties))
    |> put_change(:default_variety, default_variety || List.first(varieties))
  end

  defp parse_varieties(varieties_text) when is_binary(varieties_text) do
    varieties_text
    |> String.split(~r/[\n,]+/, trim: true)
    |> normalize_variety_list()
  end

  defp parse_varieties(_), do: []

  defp normalize_variety_list(varieties) when is_list(varieties) do
    varieties
    |> Enum.map(&normalize_variety_name/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp normalize_variety_list(_), do: []

  defp maybe_add_default(varieties, nil), do: varieties

  defp maybe_add_default(varieties, default_variety),
    do: Enum.uniq(varieties ++ [default_variety])

  defp normalize_variety_name(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_variety_name(_), do: nil
end
