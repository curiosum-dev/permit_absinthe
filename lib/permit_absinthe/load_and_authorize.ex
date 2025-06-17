defmodule Permit.Absinthe.LoadAndAuthorize do
  alias Permit.Absinthe.Schema.{Helpers, Meta}

  @doc """
  Resolves and authorizes a resource or list of resources.

  This function can be used as a resolver function directly or called from a custom resolver.

  ## Parameters

  * `args` - The arguments passed to the field
  * `resolution` - The Absinthe resolution struct

  ## Examples

      # As a resolver function
      field :post, :post do
        arg :id, non_null(:id)
        resolve &load_and_authorize/2
      end

      # Resolver for a list of resources
      field :posts, list_of(:post) do
        resolve &load_and_authorize/2
      end

      # From a custom resolver
      def my_custom_resolver(parent, args, resolution) do
        case load_and_authorize(parent, args, resolution, :one) do
          {:ok, resource} ->
            # Do something with the authorized resource
            {:ok, transform_resource(resource)}

          error ->
            error
        end
      end
  """
  def load_and_authorize(args, resolution) do
    type_meta = Meta.get_type_meta_from_resolution(resolution, :permit)
    field_meta = Meta.get_field_meta_from_resolution(resolution, :permit)

    module = type_meta[:schema]
    action = field_meta[:action] || Helpers.default_action(resolution)

    authorization_module =
      Meta.get_field_meta_from_resolution(resolution, :authorization_module)

    arity =
      case resolution.definition.schema_node.type do
        %Absinthe.Type.List{} -> :all
        _ -> :one
      end

    case authorization_module.resolver_module().resolve(
           resolution.context[:current_user],
           authorization_module,
           module,
           action,
           %{
             params: args,
             resolution: resolution,
             base_query: field_meta[:base_query] || (&Helpers.base_query/1)
           },
           arity
         ) do
      {:authorized, resource} ->
        {:ok, resource}

      :unauthorized ->
        {:error, "Unauthorized"}

      :not_found ->
        {:error, "Not found"}
    end
  end
end
