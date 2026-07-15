alias ChasingSun.Accounts
alias ChasingSun.Finance
alias ChasingSun.Harvesting
alias ChasingSun.Operations
alias ChasingSun.Repo
alias ChasingSun.Harvesting.HarvestRecord
alias ChasingSun.Finance.{DeliveryNote, Invoice, Transaction}

import Ecto.Query

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

guest_email = "guest@gmail.com"

guest_defaults = %{
  email: guest_email,
  password: "123456",
  allowed_pages: [],
  allowed_sections: ChasingSun.Accounts.Scope.guest_section_keys(),
  allowed_venture_codes: []
}

case Accounts.get_user_by_email(guest_email) do
  nil ->
    {:ok, _user} = Accounts.create_guest_user(guest_defaults)

  user ->
    {:ok, _updated_user} = Accounts.update_guest_user(user, guest_defaults)
end

accountant_email = "accountant@gmail.com"

case Accounts.get_user_by_email(accountant_email) do
  nil ->
    {:ok, _user} =
      Accounts.register_user(%{
        email: accountant_email,
        password: "123456",
        role: :accountant
      })

  user ->
    {:ok, _updated_user} = Accounts.update_user_role(user, :accountant)
end

executive_email = "executive@gmail.com"

case Accounts.get_user_by_email(executive_email) do
  nil ->
    {:ok, _user} =
      Accounts.register_user(%{
        email: executive_email,
        password: "123456",
        role: :executive
      })

  user ->
    {:ok, _updated_user} = Accounts.update_user_role(user, :executive)
end

seed_clients = [
  %{
    name: "Greenfield Packhouse Ltd",
    type: :packhouse,
    contact_person: "Wanjiru Kamau",
    phone: "+254712345001",
    email: "procurement@greenfieldpackhouse.co.ke"
  },
  %{
    name: "Naivasha Lakeview Hotel",
    type: :hotel,
    contact_person: "David Otieno",
    phone: "+254712345002",
    email: "purchasing@lakeviewhotel.co.ke"
  },
  %{
    name: "Highland Tea Exporters",
    type: :tea_company,
    contact_person: "Grace Njeri",
    phone: "+254712345003",
    email: "grace@highlandtea.co.ke"
  },
  %{
    name: "EastAfrica Spice Traders",
    type: :spice_company,
    contact_person: "Ahmed Yusuf",
    phone: "+254712345004",
    email: "ahmed@eastafricaspice.co.ke"
  }
]

Enum.each(seed_clients, fn attrs ->
  case Enum.find(Finance.list_clients(), &(&1.name == attrs.name)) do
    nil -> Finance.create_client(attrs, admin)
    client -> Finance.update_client(client, attrs, admin)
  end
end)

clients_by_name =
  Finance.list_clients()
  |> Map.new(&{&1.name, &1})

seed_transactions = [
  %{
    type: :revenue,
    business_line: :horticulture,
    amount: "168000.00",
    occurred_on: "2026-07-15",
    client: "Greenfield Packhouse Ltd",
    category: "produce_sale",
    description: "Seed finance revenue - cucumber delivery to Greenfield"
  },
  %{
    type: :revenue,
    business_line: :commodity,
    amount: "245000.00",
    occurred_on: "2026-07-14",
    client: "Highland Tea Exporters",
    category: "bulk_supply",
    description: "Seed finance revenue - herbs and aromatics supply"
  },
  %{
    type: :expense,
    business_line: :horticulture,
    amount: "42000.00",
    occurred_on: "2026-07-13",
    category: "inputs",
    description: "Seed finance expense - greenhouse nutrients"
  },
  %{
    type: :expense,
    business_line: :commodity,
    amount: "31500.00",
    occurred_on: "2026-07-12",
    client: "EastAfrica Spice Traders",
    category: "transport",
    description: "Seed finance expense - commodity logistics"
  },
  %{
    type: :revenue,
    business_line: :horticulture,
    amount: "73500.00",
    occurred_on: "2026-07-10",
    client: "Naivasha Lakeview Hotel",
    category: "produce_sale",
    description: "Seed finance revenue - hotel fresh produce order"
  }
]

seeded_transactions =
  Map.new(seed_transactions, fn attrs ->
    attrs =
      attrs
      |> Map.put(:client_id, attrs[:client] && Map.fetch!(clients_by_name, attrs.client).id)
      |> Map.put(:recorded_by_id, admin.id)
      |> Map.delete(:client)

    transaction =
      case Repo.get_by(Transaction, description: attrs.description) do
        nil ->
          %Transaction{}
          |> Transaction.changeset(attrs)
          |> Repo.insert!()

        transaction ->
          transaction
          |> Transaction.changeset(attrs)
          |> Repo.update!()
      end

    {transaction.description, transaction}
  end)

seed_invoices = [
  %{
    invoice_number: "CS-2026-SEED-001",
    status: :sent,
    due_date: "2026-07-28",
    business_line: :horticulture,
    client: "Greenfield Packhouse Ltd",
    line_items: [
      %{description: "Cucumber grade A - 1,200 kg", quantity: "1200", unit_price: "90.00"},
      %{description: "Capsicum mixed color - 500 kg", quantity: "500", unit_price: "120.00"}
    ]
  },
  %{
    invoice_number: "CS-2026-SEED-002",
    status: :paid,
    due_date: "2026-07-20",
    business_line: :horticulture,
    client: "Naivasha Lakeview Hotel",
    transaction_description: "Seed finance revenue - hotel fresh produce order",
    line_items: [
      %{description: "Chef selection vegetables", quantity: "350", unit_price: "150.00"},
      %{description: "Weekly fresh herb bundle", quantity: "70", unit_price: "300.00"}
    ]
  },
  %{
    invoice_number: "CS-2026-SEED-003",
    status: :draft,
    due_date: "2026-08-05",
    business_line: :commodity,
    client: "EastAfrica Spice Traders",
    line_items: [
      %{description: "Dried herbs trial lot", quantity: "180", unit_price: "475.00"},
      %{description: "Sorting and handling", quantity: "1", unit_price: "12500.00"}
    ]
  }
]

Enum.each(seed_invoices, fn attrs ->
  attrs =
    attrs
    |> Map.put(:client_id, Map.fetch!(clients_by_name, attrs.client).id)
    |> Map.put(
      :transaction_id,
      attrs[:transaction_description] &&
        Map.fetch!(seeded_transactions, attrs.transaction_description).id
    )
    |> Map.delete(:client)
    |> Map.delete(:transaction_description)

  case Repo.get_by(Invoice, invoice_number: attrs.invoice_number) do
    nil ->
      %Invoice{}
      |> Invoice.changeset(attrs)
      |> Repo.insert!()

    invoice ->
      invoice
      |> Invoice.changeset(attrs)
      |> Repo.update!()
  end
end)

seed_delivery_notes = [
  %{
    order_reference: "DN-SEED-2026-001",
    client: "Greenfield Packhouse Ltd",
    dispatched_on: "2026-07-15",
    signed_by: "Wanjiru Kamau",
    status: :delivered,
    items: [
      %{product: "Cucumber grade A", quantity_mt: "1.20", unit: "MT"},
      %{product: "Capsicum mixed color", quantity_mt: "0.50", unit: "MT"}
    ]
  },
  %{
    order_reference: "DN-SEED-2026-002",
    client: "Naivasha Lakeview Hotel",
    dispatched_on: "2026-07-10",
    signed_by: "David Otieno",
    status: :delivered,
    items: [
      %{product: "Chef selection vegetables", quantity_mt: "0.35", unit: "MT"},
      %{product: "Fresh herb bundle", quantity_mt: "0.07", unit: "MT"}
    ]
  },
  %{
    order_reference: "DN-SEED-2026-003",
    client: "EastAfrica Spice Traders",
    dispatched_on: "2026-07-16",
    status: :pending,
    items: [
      %{product: "Dried herbs trial lot", quantity_mt: "0.18", unit: "MT"}
    ]
  }
]

Enum.each(seed_delivery_notes, fn attrs ->
  attrs =
    attrs
    |> Map.put(:client_id, Map.fetch!(clients_by_name, attrs.client).id)
    |> Map.delete(:client)

  case Repo.get_by(DeliveryNote, order_reference: attrs.order_reference) do
    nil ->
      %DeliveryNote{}
      |> DeliveryNote.changeset(attrs)
      |> Repo.insert!()

    delivery_note ->
      delivery_note
      |> DeliveryNote.changeset(attrs)
      |> Repo.update!()
  end
end)

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

  Repo.delete_all(
    from record in HarvestRecord,
      where:
        record.greenhouse_id == ^greenhouse.id and
          record.week_ending_on == ^Date.from_iso8601!(attrs.week_ending_on) and
          record.notes == "Seeded legacy harvest"
  )

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

IO.puts("""

Seed complete.

Seeded logins:
- admin@gmail.com / 123456 (admin)
- guest@gmail.com / 123456 (restricted guest)
- accountant@gmail.com / 123456 (accountant)
- executive@gmail.com / 123456 (executive)

Seeded data:
- #{length(rules)} crop rules
- #{map_size(ventures)} ventures
- #{length(seed_greenhouses)} greenhouses with active crop cycles
- #{length(seed_harvest_records)} harvest records
- #{length(seed_clients)} finance clients
- #{length(seed_transactions)} finance transactions
- #{length(seed_invoices)} finance invoices
- #{length(seed_delivery_notes)} finance delivery notes
""")

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
