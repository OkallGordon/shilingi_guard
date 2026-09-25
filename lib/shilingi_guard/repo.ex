defmodule ShilingiGuard.Repo do
  use Ecto.Repo,
    otp_app: :shilingi_guard,
    adapter: Ecto.Adapters.Postgres
end
