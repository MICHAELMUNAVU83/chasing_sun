alias ChasingSun.Accounts
alias ChasingSun.Operations

Operations.ensure_venture_seeded()

rules = [
  %{
    crop_type: "Capsicum",
    nursery_days: 45,
    days_to_harvest: 90,
    harvest_period_days: 150,
    default_variety: "Passarella / Ilanga",
    expected_yield_1000: 200.0,
    expected_yield_2000: 350.0,
    price_per_unit: 120.0,
    active: true
  },
  %{
    crop_type: "Cucumber",
    days_to_harvest: 45,
    harvest_period_days: 120,
    expected_yield_1000: 400.0,
    expected_yield_2000: 700.0,
    price_per_unit: 90.0,
    active: true
  },
  %{
    crop_type: "Local Cucumber",
    days_to_harvest: 60,
    harvest_period_days: 90,
    default_variety: "Mydas RZ",
    forced_size: "16x40",
    flat_expected_yield: 600.0,
    price_per_unit: 90.0,
    active: true
  },
  %{crop_type: "Asparagus", flat_expected_yield: 150.0, price_per_unit: 600.0, active: true}
]

Enum.each(rules, fn attrs ->
  case Enum.find(Operations.list_crop_rules(), &(&1.crop_type == attrs.crop_type)) do
    nil -> Operations.create_crop_rule(attrs)
    rule -> Operations.update_crop_rule(rule, attrs)
  end
end)

admin_email = "admin@gmail.com"

admin =
  case Accounts.get_user_by_email(admin_email) do
    nil ->
      {:ok, user} =
        Accounts.register_user(%{email: admin_email, password: "123456", role: :admin})

      user

    user ->
      {:ok, updated_user} = Accounts.update_user_role(user, :admin)
      updated_user
  end

ventures = Map.new(Operations.list_ventures(), &{&1.code, &1})

sample_greenhouses = [
  %{
    sequence_no: 1,
    name: "Tharakanithi-01",
    size: "1000 plants",
    tank: "A1",
    venture_id: ventures["cs"].id,
    active: true,
    cycle: %{
      crop_type: "Capsicum",
      plant_count: 1000,
      nursery_date: Date.add(Date.utc_today(), -150) |> Date.to_iso8601()
    }
  },
  %{
    sequence_no: 2,
    name: "Meru-02",
    size: "2000 plants",
    tank: "B2",
    venture_id: ventures["cs"].id,
    active: true,
    cycle: %{
      crop_type: "Cucumber",
      plant_count: 2000,
      transplant_date: Date.add(Date.utc_today(), -35) |> Date.to_iso8601()
    }
  },
  %{
    sequence_no: 3,
    name: "Nyeri-03",
    size: "1000 plants",
    tank: "C3",
    venture_id: ventures["csg"].id,
    active: true,
    cycle: %{
      crop_type: "Local Cucumber",
      plant_count: 1000,
      transplant_date: Date.add(Date.utc_today(), -70) |> Date.to_iso8601()
    }
  }
]

Enum.each(sample_greenhouses, fn attrs ->
  cycle = Map.fetch!(attrs, :cycle)
  greenhouse_attrs = Map.drop(attrs, [:cycle])

  case Enum.find(Operations.list_greenhouses(), &(&1.name == attrs.name)) do
    nil ->
      {:ok, greenhouse} = Operations.create_greenhouse(greenhouse_attrs, cycle, admin)

      Enum.each(0..2, fn index ->
        week_ending_on =
          Date.add(
            ChasingSun.Operations.CropPlanner.next_saturday(Date.utc_today()),
            -(index * 7)
          )

        actual_yield = [215.0, 228.0, 240.0] |> Enum.at(index, 0)

        ChasingSun.Harvesting.upsert_harvest_record(
          %{
            greenhouse_id: greenhouse.id,
            week_ending_on: Date.to_iso8601(week_ending_on),
            actual_yield: actual_yield,
            notes: "Seeded sample harvest"
          },
          admin
        )
      end)

    greenhouse ->
      Operations.update_greenhouse(greenhouse, greenhouse_attrs, cycle, admin)
  end
end)

# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     ChasingSun.Repo.insert!(%ChasingSun.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
