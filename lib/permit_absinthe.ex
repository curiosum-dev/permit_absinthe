defmodule Permit.Absinthe do
  @moduledoc """
  Permit.Absinthe provides integration between the Permit authorization library
  and Absinthe GraphQL for Elixir.

  ## Usage

  Add this to your Absinthe schema:

      defmodule MyApp.Schema do
        use Absinthe.Schema
        use Permit.Absinthe, authorization_module: MyApp.Authorization

        # Your schema definition...
      end

  ## Options

  - `authorization_module` (required) - Your Permit authorization module
  - `auto_load_and_authorize` (optional) - Automatically add `@loadAndAuthorize`
    directives to all root query and mutation fields. Defaults to `false`.

  ## Auto Load and Authorize

  When `auto_load_and_authorize: true` is set, this library will automatically:

  1. Add the `AuthorizationPhase` to your schema's compilation pipeline
  2. Set up the necessary module attributes
  3. Add `@loadAndAuthorize` directives to all root query and mutation fields

  Example:

      defmodule MyApp.Schema do
        use Absinthe.Schema
        use Permit.Absinthe,
          authorization_module: MyApp.Authorization,
          auto_load_and_authorize: true

        query do
          field :users, list_of(:user)    # Gets @loadAndAuthorize automatically
          field :posts, list_of(:post)    # Gets @loadAndAuthorize automatically
        end
      end

  This is equivalent to manually adding the directive to each field, but much more convenient.
  """
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

  # @doc """
  # Absinthe resolver that loads and authorizes a single resource.

  # ## Example

  #   ```elixir
  #   field :article, :article do
  #     permit action: :show

  #     resolve &load_and_authorize/2
  #   end
  #   ```
  # """

  @doc """
  Absinthe resolver that loads and authorizes a list of resources or a single resource.

  ## Example

    ```elixir
    field :articles, list_of(:article) do
      permit action: :index

      resolve &load_and_authorize/2
    end

    field :article, :article do
      permit action: :show

      resolve &load_and_authorize/2
    end
    ```
  """

  defdelegate load_and_authorize(args, resolution), to: Permit.Absinthe.LoadAndAuthorize

  defmacro __using__(opts) do
    authorization_module = opts[:authorization_module]
    auto_load_and_authorize = opts[:auto_load_and_authorize]

    Module.put_attribute(
      __CALLER__.module,
      :authorization_module,
      Macro.expand(authorization_module, __ENV__)
    )

    # If auto_load_and_authorize is enabled, set up the necessary attributes and pipeline modifier
    if auto_load_and_authorize do
      Module.put_attribute(__CALLER__.module, :auto_load_and_authorize, true)
      Module.register_attribute(__CALLER__.module, :auto_load_and_authorize, persist: true)

      # Add the pipeline modifier automatically
      Module.put_attribute(
        __CALLER__.module,
        :pipeline_modifier,
        {Permit.Absinthe.Schema.AuthorizationPhase, :pipeline}
      )
    end

    quote do
      import unquote(__MODULE__)
    end
  end
end
