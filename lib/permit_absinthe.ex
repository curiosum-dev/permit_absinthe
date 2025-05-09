defmodule Permit.Absinthe do
  use Absinthe.Schema.Notation

  alias Permit.Absinthe.Schema.{Helpers, Meta}

  # @doc """
  # Adds Permit metadata to the field. Most importantly, it allows specifying:
  # - the Ecto schema (or resource struct) that a GraphQL type maps to,
  # - the Permit action that the GraphQL field is allowed to perform on the resource.

  # ## Example

  #   ```elixir
  #   object :article do
  #     permit schema: Blog.Content.Article
  #   end

  #   field :articles, list_of(:article) do
  #     permit action: :read
  #   end
  #   ```
  # """

  defmacro permit(opts) do
    authorization_module = Module.get_attribute(__CALLER__.module, :authorization_module)

    quote do
      meta(
        permit: unquote(opts),
        authorization_module: unquote(authorization_module)
      )
    end
  end

  @doc """
  Absinthe resolver that loads and authorizes a single resource.

  ## Example

    ```elixir
    field :article, :article do
      permit action: :show

      resolve &load_and_authorize_one/3
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
      permit action: :index

      resolve &load_and_authorize_all/3
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
    action = field_meta[:action] || Helpers.default_action(resolution)

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

  defmacro __using__(opts) do
    authorization_module = opts[:authorization_module]

    Module.put_attribute(
      __CALLER__.module,
      :authorization_module,
      Macro.expand(authorization_module, __ENV__)
    )

    quote do
      import unquote(__MODULE__)

      def load_and_authorize_one(parent, args, resolution) do
        unquote(__MODULE__).load_and_authorize_one(
          @authorization_module,
          parent,
          args,
          resolution
        )
      end

      def load_and_authorize_all(parent, args, resolution) do
        unquote(__MODULE__).load_and_authorize_all(
          @authorization_module,
          parent,
          args,
          resolution
        )
      end
    end
  end
end
