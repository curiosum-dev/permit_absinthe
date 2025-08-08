defmodule Permit.Absinthe.Schema.Prototype do
  @moduledoc """
  Prototype schema for Absinthe.

  This module defines the `:load_and_authorize` directive, which is used to authorize
  fields in the schema.

  ## Usage

  Add the prototype schema to your schema:

      defmodule MyAppWeb.Schema do
        use Absinthe.Schema

        @prototype_schema Permit.Absinthe.Schema.Prototype

        # Your schema definition...

        query do
          field :items, list_of(:item), directives: [:load_and_authorize] do
            permit(action: :read)

            resolve(fn _, %{context: %{loaded_resources: items}} ->
              {:ok, items}
            end)
          end
        end
      end
  """
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
