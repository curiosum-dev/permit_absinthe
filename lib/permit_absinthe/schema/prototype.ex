defmodule Permit.Absinthe.Schema.Prototype do
  @moduledoc false
  use Absinthe.Schema.Prototype

  directive :load_and_authorize do
    on([:field_definition, :object])

    description("Authorizes a field")

    expand(fn _args, node ->
      existing = node.middleware || []

      arity =
        case node.type do
          %Absinthe.Blueprint.TypeReference.List{} -> :all
          _ -> :one
        end

      %{node | middleware: [{Permit.Absinthe.Middleware.LoadAndAuthorize, arity} | existing]}
    end)
  end
end
