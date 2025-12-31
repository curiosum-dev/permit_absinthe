import Config

config :permit_absinthe_demo, PermitAbsintheDemo.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "permit_absinthe_demo_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5

config :permit_absinthe_demo, PermitAbsintheDemoWeb.Endpoint, server: false
