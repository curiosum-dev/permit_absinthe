defmodule Permit.Absinthe do
  @moduledoc """
  Integration between Permit authorization and Absinthe GraphQL.

  This lets you map GraphQL types to Ecto schemas and automatically handle
  authorization in your resolvers. No more manually checking permissions
  in every resolver or worrying about unauthorized data leaking through.

  Basic setup - add it to your schema:

      defmodule MyAppWeb.Schema do
        use Absinthe.Schema
        use Permit.Absinthe, authorization_module: MyApp.Authorization
      end

  Map GraphQL types to schemas:

      object :post do
        permit schema: MyApp.Blog.Post
        field :id, :id
        field :title, :string
      end

  Then use the built-in resolvers for automatic loading and authorization:

      query do
        field :post, :post do
          arg :id, non_null(:id)
          resolve &load_and_authorize/2  # loads and checks permissions
        end

        field :posts, list_of(:post) do
          resolve &load_and_authorize/2  # returns only accessible posts
        end
      end

  Custom ID fields work too:

      field :post_by_slug, :post do
        permit action: :read, id_param_name: :slug, id_struct_field_name: :slug
        arg :slug, non_null(:string)
        resolve &load_and_authorize/2
      end

  For mutations and complex scenarios, use middleware and a custom resolver instead:

      field :update_post, :post do
        permit action: :update
        middleware Permit.Absinthe.Middleware.LoadAndAuthorize
        resolve fn _, args, %{context: %{loaded_resource: post}} ->
          # post is already loaded and authorized
          MyApp.Blog.update_post(post, args)
        end
      end

    Works with Dataloader for efficient batch loading:

      field :comments, list_of(:comment) do
        permit action: :read
        resolve &authorized_dataloader/3
      end

  You can also use directives if visibility in the schema is important. Add the prototype schema:

      # Inside the schema module
      @prototype_schema Permit.Absinthe.Schema.Prototype

  Then use the `:load_and_authorize` directive on fields:

      field :posts, list_of(:post), directives: [:load_and_authorize] do
        permit action: :read
        resolve fn _, _, %{context: %{loaded_resources: posts}} ->
          {:ok, posts}
        end
      end

  Authorization happens automatically based on your Permit rules. Returns
  `{:error, "Unauthorized"}` or `{:error, "Not found"}` when access is denied.
  """
  use Absinthe.Schema.Notation

  @doc """
  Maps GraphQL types and fields to Permit resources and actions.

  Use this to tell Permit which Ecto schema a GraphQL type represents,
  what action to authorize, or customize how resources are loaded.

  Map a type to a schema:

      object :article do
        permit schema: Blog.Content.Article
        # ...
      end

  Specify an action for a field:

      field :create_article, :article do
        permit action: :create
        # ...
      end

  Custom ID lookups:

      field :article_by_slug, :article do
        permit action: :read, id_param_name: :slug, id_struct_field_name: :slug
        # ...
      end

  Options:
  - `:schema` - Ecto schema this type represents
  - `:action` - Action to authorize (required for mutations, defaults to `:read`)
  - `:id_param_name` - Parameter name for lookups (defaults to `:id`)
  - `:id_struct_field_name` - Struct field to match against (defaults to `:id`)
  """

  defmacro permit(opts) do
    authorization_module = Module.get_attribute(__CALLER__.module, :authorization_module)

    quote do
      meta(
        permit: unquote(opts),
        authorization_module: unquote(authorization_module)
      )
    end
  end

  defdelegate load_and_authorize(args, resolution), to: Permit.Absinthe.Resolvers.LoadAndAuthorize

  @doc """
  Dataloader resolver that batches queries while checking authorization.

  Prevents N+1 queries by batching database calls, but still applies your
  Permit authorization rules. Great for loading associations efficiently.

  Use it like a standard dataloader resolver:

      object :post do
        permit schema: MyApp.Blog.Post
        field :id, :id
        field :title, :string
        field :comments, list_of(:comment), resolve: &authorized_dataloader/3
      end

  You'll need to set up Dataloader in your schema as usual:

      def plugins do
        [Absinthe.Middleware.Dataloader | Absinthe.Plugin.defaults()]
      end

  And add the dataloader setup middleware to fields that use it:

      field :post, :post do
        permit action: :read
        middleware Permit.Absinthe.Middleware.DataloaderSetup
      end
  """

  # Dialyzer ignore explained in Permit.Absinthe.Resolvers.Dataloader
  @dialyzer {:no_return, authorized_dataloader: 3}
  defdelegate authorized_dataloader(parent, args, resolution),
    to: Permit.Absinthe.Resolvers.Dataloader

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
