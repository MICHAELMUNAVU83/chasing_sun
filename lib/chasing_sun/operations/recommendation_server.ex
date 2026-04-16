defmodule ChasingSun.Operations.RecommendationServer do
  @moduledoc false

  use GenServer

  alias ChasingSun.Operations

  @day_ms :timer.hours(24)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def refresh_now do
    GenServer.cast(__MODULE__, :refresh_now)
  end

  @impl true
  def init(_opts) do
    send(self(), :refresh)
    {:ok, %{}}
  end

  @impl true
  def handle_cast(:refresh_now, state) do
    send(self(), :refresh)
    {:noreply, state}
  end

  @impl true
  def handle_info(:refresh, state) do
    Operations.refresh_daily_operations()
    Process.send_after(self(), :refresh, @day_ms)
    {:noreply, state}
  end
end
