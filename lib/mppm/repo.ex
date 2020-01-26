defmodule Mppm.Repo do
  use Ecto.Repo,
    otp_app: :mppm,
    adapter: Ecto.Adapters.Postgres
end
