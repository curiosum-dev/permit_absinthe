import Config

config :permit_absinthe_demo,
  ecto_repos: [PermitAbsintheDemo.Repo]

config :permit_absinthe_demo, PermitAbsintheDemo.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "permit_absinthe_demo_dev",
  pool_size: 10

config :permit_absinthe_demo, PermitAbsintheDemoWeb.Endpoint,
  url: [host: "localhost"],
  http: [ip: {127, 0, 0, 1}, port: 4001],
  render_errors: [formats: [json: PermitAbsintheDemoWeb.ErrorJSON], layout: false],
  pubsub_server: PermitAbsintheDemo.PubSub,
  secret_key_base: "p8OaiCXqJm7D0gkJmD6ZbM2W7t8c3dTxF9mTyXo8tR3Tq4lVnN9b8QvS5Gf1Lp9k",
  server: true,
  check_origin: false

config :phoenix, :json_library, Jason

import_config "#{Mix.env()}.exs"
