defmodule Permit.Absinthe.Middleware.LoadAndAuthorize do
  alias Permit.Absinthe.Schema.{Helpers, Meta}

  def call(resolution, arity) when arity in [:one, :all] do
    type_meta = Meta.get_type_meta_from_resolution(resolution, :permit)

    field_meta =
      Meta.get_field_meta_from_resolution(resolution, :permit)

    module = type_meta[:schema]
    action = field_meta[:action] || Helpers.default_action(resolution)

    authorization_module =
      Meta.get_field_meta_from_resolution(resolution, :authorization_module)

    case authorization_module.resolver_module().resolve(
           resolution.context[:current_user],
           authorization_module,
           module,
           action,
           %{
             params: resolution.arguments,
             resolution: resolution,
             base_query: field_meta[:base_query] || (&Helpers.base_query/1)
           },
           arity
         ) do
      {:authorized, resource} ->
        key =
          case arity do
            :one -> :loaded_resource
            :all -> :loaded_resources
          end

        new_context = Map.put(resolution.context, key, resource)
        %{resolution | context: new_context}

      :unauthorized ->
        Absinthe.Resolution.put_result(resolution, {:error, "Unauthorized"})

      :not_found ->
        Absinthe.Resolution.put_result(resolution, {:error, "Not found"})
    end
  end
end
