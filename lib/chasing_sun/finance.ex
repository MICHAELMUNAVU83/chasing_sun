defmodule ChasingSun.Finance do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias ChasingSun.Repo
  alias ChasingSun.Accounts.User
  alias ChasingSun.Operations.AuditEvent

  alias ChasingSun.Finance.{
    Client,
    DeliveryNote,
    Invoice,
    InvoiceNumberSequence,
    Transaction
  }

  @finance_topic "finance:updates"

  def finance_topic, do: @finance_topic

  ## Clients

  def list_clients(filters \\ %{}) do
    filters = stringify_keys(filters)

    Client
    |> order_by([c], asc: c.name)
    |> maybe_filter_client_name(filters["query"])
    |> maybe_filter_field(:type, filters["type"])
    |> Repo.all()
  end

  def get_client!(id), do: Repo.get!(Client, id)

  def change_client(client, attrs \\ %{}), do: Client.changeset(client, attrs)

  def create_client(attrs, actor \\ nil) do
    %Client{}
    |> Client.changeset(attrs)
    |> Repo.insert()
    |> audit_result(actor, "client", "client_created")
  end

  def update_client(client, attrs, actor \\ nil) do
    client
    |> Client.changeset(attrs)
    |> Repo.update()
    |> audit_result(actor, "client", "client_updated")
  end

  def client_options do
    Repo.all(from c in Client, order_by: [asc: c.name], select: {c.name, c.id})
  end

  ## Transactions

  def list_transactions(filters \\ %{}) do
    filters = stringify_keys(filters)

    Transaction
    |> preload([:client, :recorded_by])
    |> maybe_filter_date_range(filters["date_from"], filters["date_to"])
    |> maybe_filter_field(:business_line, filters["business_line"])
    |> maybe_filter_field(:type, filters["type"])
    |> maybe_filter_field(:category, filters["category"])
    |> maybe_filter_field(:client_id, filters["client_id"])
    |> order_by_sort(filters["sort_by"], filters["sort_dir"])
    |> Repo.all()
  end

  def get_transaction!(id) do
    Transaction
    |> Repo.get!(id)
    |> Repo.preload([:client, :recorded_by])
  end

  def change_transaction(transaction, attrs \\ %{}), do: Transaction.changeset(transaction, attrs)

  def create_transaction(attrs, actor \\ nil) do
    Multi.new()
    |> Multi.insert(
      :transaction,
      Transaction.changeset(%Transaction{}, normalize_transaction_attrs(attrs, actor))
    )
    |> Multi.run(:audit, fn repo, %{transaction: transaction} ->
      insert_audit(repo, actor, "transaction", transaction.id, "transaction_created", %{
        type: transaction.type,
        business_line: transaction.business_line,
        amount: Decimal.to_string(transaction.amount)
      })
    end)
    |> Repo.transaction()
    |> unwrap_transaction(:transaction)
    |> case do
      {:ok, transaction} ->
        transaction = Repo.preload(transaction, [:client, :recorded_by])
        broadcast_transaction_created(transaction)
        {:ok, transaction}

      error ->
        error
    end
  end

  def update_transaction(transaction, attrs, actor \\ nil) do
    transaction
    |> Transaction.changeset(attrs)
    |> Repo.update()
    |> audit_result(actor, "transaction", "transaction_updated")
    |> preload_client_result()
  end

  defp normalize_transaction_attrs(attrs, actor) do
    attrs
    |> stringify_keys()
    |> Map.put_new("recorded_by_id", actor && actor.id)
  end

  ## Dashboard aggregation

  def dashboard_totals(reference_date \\ Date.utc_today()) do
    %{
      today: totals_for_range(reference_date, reference_date),
      week: totals_for_range(Date.beginning_of_week(reference_date), reference_date),
      month: totals_for_range(Date.beginning_of_month(reference_date), reference_date)
    }
  end

  defp totals_for_range(from_date, to_date) do
    rows =
      Repo.all(
        from t in Transaction,
          where: t.occurred_on >= ^from_date and t.occurred_on <= ^to_date,
          group_by: [t.type, t.business_line],
          select: {t.type, t.business_line, sum(t.amount)}
      )

    base = %{
      revenue: %{horticulture: Decimal.new(0), commodity: Decimal.new(0)},
      expense: %{horticulture: Decimal.new(0), commodity: Decimal.new(0)}
    }

    Enum.reduce(rows, base, fn {type, business_line, total}, acc ->
      put_in(acc, [type, business_line], total || Decimal.new(0))
    end)
  end

  def trend_last_weeks(weeks \\ 12, reference_date \\ Date.utc_today()) do
    first_week_start = Date.add(Date.beginning_of_week(reference_date), -7 * (weeks - 1))

    rows =
      Repo.all(
        from t in Transaction,
          where: t.occurred_on >= ^first_week_start,
          group_by: [fragment("date_trunc('week', ?)::date", t.occurred_on), t.type],
          select: %{
            week_start: fragment("date_trunc('week', ?)::date", t.occurred_on),
            type: t.type,
            total: sum(t.amount)
          }
      )

    totals_by_week =
      Enum.reduce(rows, %{}, fn %{week_start: week_start, type: type, total: total}, acc ->
        acc
        |> Map.put_new(week_start, %{revenue: Decimal.new(0), expense: Decimal.new(0)})
        |> put_in([week_start, type], total || Decimal.new(0))
      end)

    for offset <- (weeks - 1)..0 do
      week_start = Date.add(Date.beginning_of_week(reference_date), -7 * offset)

      totals =
        Map.get(totals_by_week, week_start, %{revenue: Decimal.new(0), expense: Decimal.new(0)})

      %{week_start: week_start, revenue: totals.revenue, expense: totals.expense}
    end
  end

  ## Invoices

  def list_invoices(filters \\ %{}) do
    filters = stringify_keys(filters)

    Invoice
    |> preload(:client)
    |> maybe_filter_field(:status, filters["status"])
    |> maybe_filter_field(:client_id, filters["client_id"])
    |> order_by([i], desc: i.inserted_at)
    |> Repo.all()
    |> Enum.map(&overlay_overdue_status/1)
  end

  def get_invoice!(id) do
    Invoice
    |> Repo.get!(id)
    |> Repo.preload([:client, :transaction])
    |> overlay_overdue_status()
  end

  def change_invoice(invoice, attrs \\ %{}), do: Invoice.changeset(invoice, attrs)

  @doc "Atomically allocates the next per-year invoice number, e.g. \"CS-2026-0001\"."
  def next_invoice_number(year \\ Date.utc_today().year) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {1, [%InvoiceNumberSequence{last_number: last_number}]} =
      Repo.insert_all(
        InvoiceNumberSequence,
        [%{year: year, last_number: 1, inserted_at: now, updated_at: now}],
        on_conflict: [inc: [last_number: 1]],
        conflict_target: :year,
        returning: [:last_number]
      )

    "CS-#{year}-#{String.pad_leading(to_string(last_number), 4, "0")}"
  end

  def create_invoice(attrs, actor \\ nil) do
    attrs = stringify_keys(attrs)

    Multi.new()
    |> Multi.insert(:invoice, fn _changes ->
      Invoice.changeset(%Invoice{}, Map.put(attrs, "invoice_number", next_invoice_number()))
    end)
    |> Multi.run(:audit, fn repo, %{invoice: invoice} ->
      insert_audit(repo, actor, "invoice", invoice.id, "invoice_created", %{
        invoice_number: invoice.invoice_number
      })
    end)
    |> Repo.transaction()
    |> unwrap_transaction(:invoice)
    |> case do
      {:ok, invoice} -> {:ok, Repo.preload(invoice, [:client, :transaction])}
      error -> error
    end
  end

  def update_invoice(invoice, attrs, actor \\ nil) do
    invoice
    |> Invoice.changeset(attrs)
    |> Repo.update()
    |> audit_result(actor, "invoice", "invoice_updated")
    |> case do
      {:ok, invoice} -> {:ok, Repo.preload(invoice, [:client, :transaction])}
      error -> error
    end
  end

  @doc """
  Marks an invoice paid. If it has no linked transaction yet, atomically
  creates one (revenue, using the invoice's own business_line and total) and
  links it back onto the invoice, so the acceptance criterion ("marking paid
  auto-creates a transaction") holds even under concurrent access.

  Returns `{:ok, invoice, auto_created_transaction?: boolean}`.
  """
  def mark_invoice_paid(%Invoice{} = invoice, actor) do
    invoice = Repo.preload(invoice, [:client, :transaction])
    had_transaction? = not is_nil(invoice.transaction_id)

    multi =
      Multi.new()
      |> Multi.update(:invoice, Invoice.changeset(invoice, %{"status" => "paid"}))

    multi =
      if had_transaction? do
        multi
      else
        multi
        |> Multi.insert(:transaction, fn _changes ->
          Transaction.changeset(%Transaction{}, %{
            "type" => "revenue",
            "business_line" => Atom.to_string(invoice.business_line),
            "amount" => Invoice.total(invoice),
            "currency" => "KES",
            "description" => "Auto-created from invoice #{invoice.invoice_number}",
            "category" => "invoice_payment",
            "occurred_on" => Date.utc_today(),
            "client_id" => invoice.client_id,
            "recorded_by_id" => actor && actor.id
          })
        end)
        |> Multi.update(:linked_invoice, fn %{invoice: updated_invoice, transaction: transaction} ->
          Invoice.changeset(updated_invoice, %{"transaction_id" => transaction.id})
        end)
      end

    multi =
      Multi.run(multi, :audit, fn repo, changes ->
        final_invoice = Map.get(changes, :linked_invoice, changes.invoice)

        insert_audit(repo, actor, "invoice", final_invoice.id, "invoice_marked_paid", %{
          invoice_number: final_invoice.invoice_number
        })
      end)

    case Repo.transaction(multi) do
      {:ok, changes} ->
        final_invoice =
          (changes[:linked_invoice] || changes.invoice)
          |> Repo.preload([:client, :transaction])

        if transaction = changes[:transaction] do
          broadcast_transaction_created(Repo.preload(transaction, [:client, :recorded_by]))
        end

        {:ok, final_invoice, auto_created_transaction?: not had_transaction?}

      {:error, _step, changeset, _changes} ->
        {:error, changeset}
    end
  end

  @doc """
  Idempotent bulk flip of `sent` invoices past their due date to `overdue`.
  Called opportunistically from LiveView mounts — no Oban job required.
  """
  def sync_overdue_invoices!(today \\ Date.utc_today()) do
    {count, _} =
      Repo.update_all(
        from(i in Invoice, where: i.status == :sent and i.due_date < ^today),
        set: [status: :overdue]
      )

    count
  end

  defp overlay_overdue_status(%Invoice{status: :sent, due_date: %Date{} = due_date} = invoice) do
    if Date.compare(due_date, Date.utc_today()) == :lt do
      %{invoice | status: :overdue}
    else
      invoice
    end
  end

  defp overlay_overdue_status(invoice), do: invoice

  ## Delivery notes

  def list_delivery_notes(filters \\ %{}) do
    filters = stringify_keys(filters)

    DeliveryNote
    |> preload(:client)
    |> maybe_filter_field(:status, filters["status"])
    |> maybe_filter_field(:client_id, filters["client_id"])
    |> order_by([d], desc: d.inserted_at)
    |> Repo.all()
  end

  def get_delivery_note!(id) do
    DeliveryNote
    |> Repo.get!(id)
    |> Repo.preload(:client)
  end

  def change_delivery_note(note, attrs \\ %{}), do: DeliveryNote.changeset(note, attrs)

  def create_delivery_note(attrs, actor \\ nil) do
    %DeliveryNote{}
    |> DeliveryNote.changeset(attrs)
    |> Repo.insert()
    |> audit_result(actor, "delivery_note", "delivery_note_created")
    |> preload_client_result()
  end

  def update_delivery_note(note, attrs, actor \\ nil) do
    note
    |> DeliveryNote.changeset(attrs)
    |> Repo.update()
    |> audit_result(actor, "delivery_note", "delivery_note_updated")
    |> preload_client_result()
  end

  ## Shared query helpers

  defp maybe_filter_client_name(query, nil), do: query
  defp maybe_filter_client_name(query, ""), do: query

  defp maybe_filter_client_name(query, name) do
    from c in query, where: ilike(c.name, ^"%#{name}%")
  end

  defp maybe_filter_field(query, _field, nil), do: query
  defp maybe_filter_field(query, _field, ""), do: query

  defp maybe_filter_field(query, field, value) when is_binary(value) do
    case Integer.parse(value) do
      {int_value, ""} -> from q in query, where: field(q, ^field) == ^int_value
      _ -> from q in query, where: field(q, ^field) == ^value
    end
  end

  defp maybe_filter_field(query, field, value) do
    from q in query, where: field(q, ^field) == ^value
  end

  defp maybe_filter_date_range(query, from_date, to_date) do
    query
    |> maybe_filter_from_date(from_date)
    |> maybe_filter_to_date(to_date)
  end

  defp maybe_filter_from_date(query, date) when date in [nil, ""], do: query

  defp maybe_filter_from_date(query, date) do
    case coerce_date(date) do
      {:ok, parsed} -> from t in query, where: t.occurred_on >= ^parsed
      :error -> query
    end
  end

  defp maybe_filter_to_date(query, date) when date in [nil, ""], do: query

  defp maybe_filter_to_date(query, date) do
    case coerce_date(date) do
      {:ok, parsed} -> from t in query, where: t.occurred_on <= ^parsed
      :error -> query
    end
  end

  defp coerce_date(%Date{} = date), do: {:ok, date}

  defp coerce_date(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, date} -> {:ok, date}
      {:error, _reason} -> :error
    end
  end

  defp coerce_date(_date), do: :error

  @sortable_transaction_fields %{
    "occurred_on" => :occurred_on,
    "amount" => :amount,
    "type" => :type,
    "business_line" => :business_line,
    "category" => :category
  }

  defp order_by_sort(query, field, dir) do
    direction = if dir == "asc", do: :asc, else: :desc

    case Map.get(@sortable_transaction_fields, field) do
      nil -> order_by(query, [t], desc: t.occurred_on)
      column -> order_by(query, [t], [{^direction, field(t, ^column)}])
    end
  end

  defp preload_client_result({:ok, struct}), do: {:ok, Repo.preload(struct, :client)}
  defp preload_client_result(error), do: error

  defp stringify_keys(attrs) when is_map(attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
  end

  defp stringify_keys(attrs), do: attrs

  defp unwrap_transaction({:ok, result}, key), do: {:ok, Map.fetch!(result, key)}
  defp unwrap_transaction({:error, _step, changeset, _}, _key), do: {:error, changeset}

  defp audit_result({:ok, struct}, actor, entity_type, action) do
    insert_audit(Repo, actor, entity_type, struct.id, action, %{})
    {:ok, struct}
  end

  defp audit_result(other, _actor, _entity_type, _action), do: other

  defp insert_audit(repo, %User{id: actor_user_id}, entity_type, entity_id, action, metadata) do
    %AuditEvent{}
    |> AuditEvent.changeset(%{
      actor_user_id: actor_user_id,
      entity_type: entity_type,
      entity_id: entity_id,
      action: action,
      metadata: metadata
    })
    |> repo.insert()
  end

  defp insert_audit(_repo, _actor, _entity_type, _entity_id, _action, _metadata), do: {:ok, nil}

  defp broadcast_transaction_created(%Transaction{} = transaction) do
    Phoenix.PubSub.broadcast(
      ChasingSun.PubSub,
      @finance_topic,
      {:transaction_created,
       %{
         id: transaction.id,
         type: transaction.type,
         business_line: transaction.business_line,
         amount: transaction.amount,
         occurred_on: transaction.occurred_on
       }}
    )
  end
end
