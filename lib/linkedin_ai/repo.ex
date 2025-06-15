defmodule LinkedinAi.Repo do
  use Ecto.Repo,
    otp_app: :linkedin_ai,
    adapter: Ecto.Adapters.Postgres
end
