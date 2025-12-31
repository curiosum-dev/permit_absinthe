defmodule PermitAbsintheDemo.Repo do
  use Ecto.Repo,
    otp_app: :permit_absinthe_demo,
    adapter: Ecto.Adapters.Postgres
end
