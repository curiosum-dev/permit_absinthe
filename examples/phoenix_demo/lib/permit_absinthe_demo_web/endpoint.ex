defmodule PermitAbsintheDemoWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :permit_absinthe_demo

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  plug PermitAbsintheDemoWeb.Router

  @impl true
  def init(_key, config), do: {:ok, config}
end
