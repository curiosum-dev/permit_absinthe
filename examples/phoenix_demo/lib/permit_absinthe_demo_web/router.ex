defmodule PermitAbsintheDemoWeb.Router do
  use Phoenix.Router

  alias PermitAbsintheDemoWeb.ContextPlug

  pipeline :api do
    plug :accepts, ["json"]
    plug ContextPlug
  end

  scope "/" do
    pipe_through :api

    forward "/graphql",
      Absinthe.Plug,
      schema: PermitAbsintheDemoWeb.Schema,
      json_codec: Jason

    forward "/graphiql",
      Absinthe.Plug.GraphiQL,
      schema: PermitAbsintheDemoWeb.Schema,
      interface: :playground,
      json_codec: Jason
  end
end
