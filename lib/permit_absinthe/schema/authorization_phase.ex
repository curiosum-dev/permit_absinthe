defmodule Permit.Absinthe.Schema.AuthorizationPhase do
  alias Absinthe.{Phase, Pipeline, Blueprint}

  @behaviour Absinthe.Phase

  @moduledoc """
  An Absinthe schema compilation phase that automatically adds `load_and_authorize` directives
  to query and mutation fields based on schema configuration.

  This phase provides optional automatic directive hydration that can be enabled by setting
  the `auto_load_and_authorize: true` option when using `Permit.Absinthe`.

  ## Usage

  To enable automatic directive hydration in your schema:

      defmodule MyApp.Schema do
        use Absinthe.Schema
        use Permit.Absinthe,
          authorization_module: MyApp.Authorization,
          auto_load_and_authorize: true

        query do
          field :users, list_of(:user)  # Will automatically get @loadAndAuthorize
          field :user, :user do         # Will automatically get @loadAndAuthorize
            arg :id, non_null(:id)
          end
        end
      end

  ## How it works

  When enabled, this phase will:
  1. Only process schemas that have `auto_load_and_authorize: true`
  2. Add `@loadAndAuthorize` directives to root query and mutation fields
  3. Skip fields that already have the directive or explicit middleware
  4. Leave object type fields and other nested fields unchanged

  ## Safety

  The phase includes several safety checks:
  - Will not add directives to fields that already have them
  - Will not add directives to fields with explicit middleware
  - Will not add directives to fields with custom resolvers
  - Only affects schemas that explicitly opt-in with the option
  """

  def pipeline(pipeline) do
    Pipeline.insert_after(
      pipeline,
      Phase.Schema.TypeImports,
      __MODULE__
    )
  end

  def run(blueprint, _) do
    # Use a simpler approach: transform the blueprint by walking and tracking state
    blueprint = Blueprint.prewalk(blueprint, &add_authorization_directive/1)
    {:ok, blueprint}
  end

  # Add directive to fields in query or mutation root types
  defp add_authorization_directive(
         %Blueprint.Schema.ObjectTypeDefinition{identifier: identifier, fields: fields} = node
       )
       when identifier in [:query, :mutation] do
    # Process each field in the root query/mutation type
    updated_fields =
      Enum.map(fields, fn field ->
        if should_hydrate_schema?(field) and should_add_directive_to_field?(field) do
          # Create a proper directive application that Absinthe will process
          directive_application = %Blueprint.Directive{
            name: "load_and_authorize",
            arguments: [],
            source_location: field.source_location
          }

          %{field | directives: [directive_application | field.directives]}
        else
          field
        end
      end)

    %{node | fields: updated_fields}
  end

  # Pass through all other nodes unchanged
  defp add_authorization_directive(node), do: node

  # Check if the schema has opted into directive hydration
  defp should_hydrate_schema?(field) do
    case field.__reference__ do
      %{module: module} when module != nil ->
        # Check if the schema module has the @auto_load_and_authorize attribute set to true
        try do
          module_attributes = module.__info__(:attributes)
          auto_load_value = Keyword.get(module_attributes, :auto_load_and_authorize)

          case auto_load_value do
            [true] -> true
            _ -> false
          end
        rescue
          _ -> false
        end

      _ ->
        false
    end
  end

  # Determine if a field should get the directive
  defp should_add_directive_to_field?(field) do
    # Don't add if the field already has the load_and_authorize directive
    # Don't add if the field already has explicit middleware
    # Don't add if the field has a custom resolver
    not has_load_and_authorize_directive?(field) and
      not has_explicit_middleware?(field) and
      not has_custom_resolver?(field)
  end

  # Check if the field already has the load_and_authorize directive
  defp has_load_and_authorize_directive?(field) do
    Enum.any?(field.directives, fn
      %Blueprint.Directive{name: "load_and_authorize"} -> true
      %{name: "load_and_authorize"} -> true
      %{identifier: :load_and_authorize} -> true
      :load_and_authorize -> true
      _ -> false
    end)
  end

  # Check if the field has explicit middleware setup
  defp has_explicit_middleware?(field) do
    case field.middleware do
      [] ->
        false

      nil ->
        false

      middleware when is_list(middleware) ->
        # Only consider it explicit if it has non-default middleware
        Enum.any?(middleware, fn
          # Default Absinthe middleware patterns that we should ignore
          {:ref, _module, _ref} -> false
          {Absinthe.Middleware.MapGet, _} -> false
          # Any other middleware is considered explicit
          _ -> true
        end)
    end
  end

  # Check if the field has a custom resolver function
  defp has_custom_resolver?(field) do
    # Check if middleware contains custom resolver patterns
    case field.middleware do
      [] ->
        false

      nil ->
        false

      middleware when is_list(middleware) ->
        Enum.any?(middleware, fn
          {{Absinthe.Resolution, :call}, _} -> true
          {module, _} when module != Absinthe.Middleware.MapGet -> true
          _ -> false
        end)
    end
  end
end
