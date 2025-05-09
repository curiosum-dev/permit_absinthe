defmodule Permit.Absinthe do
  use Absinthe.Schema.Notation

  alias Permit.Absinthe.Schema.{Helpers, Meta}

  @doc """
  Shorthand for adding the `permit` meta to the field. Most importantly, it allows specifying:
  - the Ecto schema (or resource struct) that a GraphQL type maps to,
  - the Permit action that the GraphQL field is allowed to perform on the resource.

  ## Example

    ```elixir
    object :article do
      # Equivalent to: meta(permit: [schema: Blog.Content.Article])
      permit(schema: Blog.Content.Article)
    end

    field :articles, list_of(:article) do
      # Equivalent to: meta(permit: [action: :read])
      permit(action: :read)
    end
    ```
  """
  defmacro permit(opts) do
    quote do
      meta(permit: unquote(opts))
    end
  end

  @doc """
  Absinthe resolver that loads and authorizes a single resource.

  ## Example

    ```elixir
    field :article, :article do
      permit(action: :show)

      resolve(&load_and_authorize_one/3)
    end
    ```
  """
  def load_and_authorize_one(authorization_module, parent, args, resolution) do
    load_and_authorize(:one, authorization_module, parent, args, resolution)
  end

  @doc """
  Absinthe resolver that loads and authorizes a list of resources.

  ## Example

    ```elixir
    field :articles, list_of(:article) do
      permit(action: :index)

      resolve(&load_and_authorize_all/3)
    end
    ```
  """
  def load_and_authorize_all(authorization_module, parent, args, resolution) do
    load_and_authorize(:all, authorization_module, parent, args, resolution)
  end

  defp load_and_authorize(arity, authorization_module, _parent, args, resolution)
       when arity in [:one, :all] do
    type_meta = Meta.get_type_meta_from_resolution(resolution, :permit)
    field_meta = Meta.get_field_meta_from_resolution(resolution, :permit)

    module = type_meta[:schema]
    action = field_meta[:action] || default_action(resolution)

    case authorization_module.resolver_module().resolve(
           resolution.context[:current_user],
           authorization_module,
           module,
           action,
           %{
             params: args,
             resolution: resolution,
             base_query: field_meta[:base_query] || (&base_query/1)
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

  defp base_query(%{
         resource_module: resource_module,
         resolution: resolution,
         params: params
       }) do
    field_meta = Meta.get_field_meta_from_resolution(resolution, :permit)
    param = field_meta[:id_param_name] || :id
    field = field_meta[:id_struct_field_name] || :id

    case params do
      %{^param => id} ->
        resource_module
        |> Permit.Ecto.filter_by_field(field, id)

      _ ->
        Permit.Ecto.from(resource_module)
    end
  end

  defp default_action(resolution) do
    if Helpers.mutation?(resolution) do
      raise ArgumentError,
            """
            Authorization action must be specified for mutations - e.g.: `permit action: :create`.
            For queries, `:read` is assumed by default.
            """
    else
      :read
    end
  end

  defmacro __using__(opts) do
    quote do
      import unquote(__MODULE__)

      def load_and_authorize_one(parent, args, resolution) do
        unquote(__MODULE__).load_and_authorize_one(
          unquote(opts[:authorization_module]),
          parent,
          args,
          resolution
        )
      end

      def load_and_authorize_all(parent, args, resolution) do
        unquote(__MODULE__).load_and_authorize_all(
          unquote(opts[:authorization_module]),
          parent,
          args,
          resolution
        )
      end
    end
  end
end
