import Config

config :permit_absinthe, ecto_repos: [Permit.AbsintheFakeApp.Repo]

config :permit_absinthe, Permit.AbsintheFakeApp.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  database: "permit_absinthe_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool_size: 10,
  log: false
