alias ChasingSun.Accounts
alias ChasingSun.Harvesting
alias ChasingSun.Operations

Operations.ensure_venture_seeded()

rules = [
  %{
    crop_type: "Capsicum",
    nursery_days: 45,
    days_to_harvest: 90,
    harvest_period_days: 150,
    default_variety: "Passarella / Ilanga",
    varieties: ["Passarella / Ilanga", "Buffalo F1"],
    expected_yield_1000: 200.0,
    expected_yield_2000: 350.0,
    price_per_unit: 120.0,
    active: true
  },
  %{
    crop_type: "Cucumber",
    days_to_harvest: 45,
    harvest_period_days: 120,
    default_variety: "Centinela F1",
    varieties: ["Centinela F1", "Kala F1"],
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
    varieties: ["Mydas RZ"],
    forced_size: "16x40",
    flat_expected_yield: 600.0,
    price_per_unit: 90.0,
    active: true
  },
  %{
    crop_type: "Asparagus",
    default_variety: "Mary Washington",
    varieties: ["Mary Washington"],
    flat_expected_yield: 150.0,
    price_per_unit: 600.0,
    active: true
  }
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

cs_unit_names = MapSet.new(["Tharakanithi", "Meru", "Kisii"])

venture_id_for = fn name ->
  if MapSet.member?(cs_unit_names, name), do: ventures["cs"].id, else: ventures["csg"].id
end

seed_greenhouses = [
  %{
    sequence_no: 1,
    name: "Murang'a",
    size: "8x40",
    tank: "1000 L",
    venture_id: venture_id_for.("Murang'a"),
    active: true,
    cycle: %{
      crop_type: "Cucumber",
      variety: "Centinela F1",
      plant_count: 1000,
      transplant_date: "2026-03-15",
      harvest_start_date: "2026-04-30",
      harvest_end_date: "2026-08-30"
    }
  },
  %{
    sequence_no: 2,
    name: "Wajia",
    size: "8x40",
    tank: "-",
    venture_id: venture_id_for.("Wajia"),
    active: true,
    cycle: %{
      crop_type: "Capsicum",
      variety: "Passarella / Ilanga",
      plant_count: 1000,
      nursery_date: "2025-12-31",
      transplant_date: "2026-02-14",
      harvest_start_date: "2026-05-14",
      harvest_end_date: "2026-10-14"
    }
  },
  %{
    sequence_no: 3,
    name: "Kericho",
    size: "8x40",
    tank: "500 L",
    venture_id: venture_id_for.("Kericho"),
    active: true,
    cycle: %{
      crop_type: "Capsicum",
      plant_count: 1000,
      variety: "Passarella / Ilanga",
      nursery_date: "2025-03-04",
      transplant_date: "2025-04-18",
      harvest_start_date: "2025-07-02",
      harvest_end_date: "2026-03-18"
    }
  },
  %{
    sequence_no: 4,
    name: "Homa Bay",
    size: "16x40",
    tank: "1000 L",
    venture_id: venture_id_for.("Homa Bay"),
    active: true,
    cycle: %{
      crop_type: "Cucumber",
      variety: "Centinela F1",
      plant_count: 2000,
      transplant_date: "2025-10-01",
      harvest_start_date: "2025-11-22",
      harvest_end_date: "2026-04-25"
    }
  },
  %{
    sequence_no: 5,
    name: "Lamu",
    size: "16x40",
    tank: "1000 L",
    venture_id: venture_id_for.("Lamu"),
    active: true,
    cycle: %{
      crop_type: "Capsicum",
      variety: "Passarella / Ilanga",
      plant_count: 2000,
      nursery_date: "2025-10-01",
      transplant_date: "2025-11-15",
      harvest_start_date: "2026-02-06",
      harvest_end_date: "2026-08-06"
    }
  },
  %{
    sequence_no: 6,
    name: "Tharakanithi",
    size: "16x40",
    tank: "1000 L",
    venture_id: venture_id_for.("Tharakanithi"),
    active: true,
    cycle: %{
      crop_type: "Asparagus",
      variety: "Mary Washington",
      plant_count: 1000,
      transplant_date: "2026-04-01",
      harvest_start_date: "2026-07-07",
      harvest_end_date: "2036-01-01"
    }
  },
  %{
    sequence_no: 7,
    name: "Vihiga",
    size: "16x40",
    tank: "1000 L",
    venture_id: venture_id_for.("Vihiga"),
    active: true,
    cycle: %{
      crop_type: "Capsicum",
      variety: "Passarella / Ilanga",
      plant_count: 2000,
      nursery_date: "2026-01-29",
      transplant_date: "2026-03-15",
      harvest_start_date: "2026-06-01",
      harvest_end_date: "2026-12-02"
    }
  },
  %{
    sequence_no: 8,
    name: "Meru",
    size: "16x40",
    tank: "1000 L",
    venture_id: venture_id_for.("Meru"),
    active: true,
    cycle: %{
      crop_type: "Local Cucumber",
      variety: "Mydas RZ",
      plant_count: 2000,
      transplant_date: "2026-04-12",
      harvest_start_date: "2026-06-11",
      harvest_end_date: "2026-09-09"
    }
  },
  %{
    sequence_no: 9,
    name: "Kisii",
    size: "16x40",
    tank: "1000 L",
    venture_id: venture_id_for.("Kisii"),
    active: true,
    cycle: %{
      crop_type: "Capsicum",
      variety: "Passarella / Ilanga",
      plant_count: 2000,
      nursery_date: "2026-04-02",
      transplant_date: "2026-05-17",
      harvest_start_date: "2026-08-15",
      harvest_end_date: "2027-01-12"
    }
  }
]

Enum.each(seed_greenhouses, fn attrs ->
  cycle = Map.fetch!(attrs, :cycle)
  greenhouse_attrs = Map.drop(attrs, [:cycle])

  case Enum.find(Operations.list_greenhouses(), &(&1.name == attrs.name)) do
    nil ->
      {:ok, _greenhouse} = Operations.create_greenhouse(greenhouse_attrs, cycle, admin)

    greenhouse ->
      {:ok, _greenhouse} =
        Operations.update_greenhouse(greenhouse, greenhouse_attrs, cycle, admin)
  end
end)

seed_harvest_records = [
  %{week_ending_on: "2026-02-28", greenhouse_name: "Lamu", actual_yield: 200.0},
  %{week_ending_on: "2026-02-28", greenhouse_name: "Kericho", actual_yield: 178.0},
  %{week_ending_on: "2026-02-28", greenhouse_name: "Homa Bay", actual_yield: 715.0},
  %{week_ending_on: "2026-03-07", greenhouse_name: "Homa Bay", actual_yield: 715.0},
  %{week_ending_on: "2026-03-07", greenhouse_name: "Kericho", actual_yield: 155.0},
  %{week_ending_on: "2026-03-07", greenhouse_name: "Lamu", actual_yield: 200.0},
  %{week_ending_on: "2026-03-14", greenhouse_name: "Lamu", actual_yield: 350.0},
  %{week_ending_on: "2026-03-14", greenhouse_name: "Homa Bay", actual_yield: 640.0},
  %{week_ending_on: "2026-03-21", greenhouse_name: "Lamu", actual_yield: 390.0},
  %{week_ending_on: "2026-03-21", greenhouse_name: "Homa Bay", actual_yield: 740.0},
  %{week_ending_on: "2026-03-28", greenhouse_name: "Lamu", actual_yield: 370.0},
  %{week_ending_on: "2026-03-28", greenhouse_name: "Homa Bay", actual_yield: 630.0},
  %{week_ending_on: "2026-04-04", greenhouse_name: "Lamu", actual_yield: 247.0},
  %{week_ending_on: "2026-04-04", greenhouse_name: "Homa Bay", actual_yield: 525.0}
]

greenhouses_by_name =
  Operations.list_greenhouses()
  |> Map.new(&{&1.name, &1})

Enum.each(seed_harvest_records, fn attrs ->
  greenhouse = Map.fetch!(greenhouses_by_name, attrs.greenhouse_name)

  {:ok, _record} =
    Harvesting.upsert_harvest_record(
      %{
        greenhouse_id: greenhouse.id,
        week_ending_on: attrs.week_ending_on,
        actual_yield: attrs.actual_yield,
        notes: "Seeded legacy harvest"
      },
      admin
    )
end)

Operations.refresh_daily_operations()

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
