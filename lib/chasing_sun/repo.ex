defmodule ChasingSun.Repo do
  use Ecto.Repo,
    otp_app: :chasing_sun,
    adapter: Ecto.Adapters.Postgres
end
