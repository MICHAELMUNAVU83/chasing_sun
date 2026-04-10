{:ok, _} = Application.ensure_all_started(:chasing_sun)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(ChasingSun.Repo, :manual)
