defmodule Permit.Absinthe do
  use Absinthe.Schema.Notation

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
  def load_and_authorize_one(_parent, args, resolution) do
    load_and_authorize(:one, args, resolution)
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
  def load_and_authorize_all(_parent, args, resolution) do
    load_and_authorize(:all, args, resolution)
  end

  defp load_and_authorize(arity, args, resolution)
       when arity in [:one, :all] do
    Permit.Absinthe.LoadAndAuthorize.load_and_authorize(args, resolution, arity)
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
    end
  end
end
