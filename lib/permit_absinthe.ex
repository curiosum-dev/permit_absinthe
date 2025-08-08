defmodule Permit.Absinthe do
  @moduledoc """
  Permit.Absinthe provides integration between the [Permit](https://hexdocs.pm/permit)
  authorization library and [Absinthe](https://hexdocs.pm/absinthe) GraphQL for Elixir.

  This module enables automatic authorization of GraphQL queries and mutations by mapping
  GraphQL types to Permit resource modules (typically Ecto schemas) and providing
  resolvers and middleware for seamless resource loading and authorization.

  ## Features

  - Map GraphQL types to Permit resource modules (Ecto schemas)
  - Automatically check permissions for queries and mutations
  - Resolvers for automatic resource loading and authorization
  - Middleware support for complex resolution scenarios
  - Dataloader integration for optimized N+1 query prevention
  - Directive-based authorization using `:load_and_authorize`

  ## Usage

  ### Basic Setup

  Add `Permit.Absinthe` to your schema and specify your authorization module:

      defmodule MyAppWeb.Schema do
        use Absinthe.Schema
        use Permit.Absinthe, authorization_module: MyApp.Authorization

        # Your schema definition...
      end

  ### Mapping GraphQL Types to Resources

  Use the `permit/1` macro to map GraphQL types to Ecto schemas:

      object :post do
        permit schema: MyApp.Blog.Post

        field :id, :id
        field :title, :string
        field :content, :string
      end

  ### Field-Level Authorization

  Specify actions for individual fields. Queries default to `:read` action,
  while mutations require explicit action specification:

      field :unpublished_posts, list_of(:post) do
        permit action: :view_unpublished
        resolve &PostResolver.unpublished_posts/3
      end

      field :create_post, :post do
        permit action: :create
        resolve &PostResolver.create_post/3
      end

  Custom action names are supported; ensure your module implementing
  [`Permit.Actions`](https://hexdocs.pm/permit/Permit.Actions.html)
  defines them as desired.

  ### Automatic Resource Loading and Authorization

  Use the `load_and_authorize/2` resolver for automatic resource loading:

      query do
        field :post, :post do
          permit action: :read
          arg :id, non_null(:id)
          resolve &load_and_authorize/2
        end

        field :posts, list_of(:post) do
          permit action: :read
          resolve &load_and_authorize/2
        end
      end

  ### Custom ID Parameters

  Specify custom ID parameter names and struct field names:

      field :post_by_slug, :post do
        arg :slug, non_null(:string)
        permit action: :read, id_param_name: :slug, id_struct_field_name: :slug
        resolve &load_and_authorize/2
      end

  ### Using Middleware

  For complex scenarios requiring custom resolution logic, use the middleware approach:

      mutation do
        field :update_article, :article do
          permit action: :update
          arg :id, non_null(:id)
          arg :name, non_null(:string)

          middleware Permit.Absinthe.Middleware.LoadAndAuthorize

          resolve fn _, args, %{context: %{loaded_resource: article}} ->
            MyApp.Blog.update_article(article, args)
          end
        end
      end

  ### Using Directives

  Enable the `:load_and_authorize` directive by adding the prototype schema:

      defmodule MyAppWeb.Schema do
        use Absinthe.Schema

        @prototype_schema Permit.Absinthe.Schema.Prototype

        query do
          field :items, list_of(:item), directives: [:load_and_authorize] do
            permit action: :read

            resolve fn _, _, %{context: %{loaded_resources: items}} ->
              {:ok, items}
            end
          end
        end
      end

  ### Dataloader Integration

  For optimized batch loading with authorization, use the `authorized_dataloader/3` resolver:

      field :posts, list_of(:post) do
        resolve &authorized_dataloader/3
      end

  ## Authorization Flow

  1. **Type mapping**: GraphQL types are mapped to Ecto schemas using `permit schema: Module`
  2. **Action determination**: Actions are specified via `permit action: :action_name` or default to `:read` for queries
  3. **Resource loading**: Resources are loaded based on query parameters and field metadata
  4. **Authorization check**: Permit authorization rules are applied using the configured authorization module
  5. **Result return**: Authorized resources are returned, or authorization errors are returned

  ## Error Handling

  - Returns `{:error, "Unauthorized"}` when authorization fails
  - Returns `{:error, "Not found"}` when resources don't exist or aren't accessible
  - Raises `ArgumentError` when required action is not specified for mutations

  ## Integration with Permit Ecosystem

  This module works seamlessly with:
  - `Permit` - Core authorization library
  - `Permit.Ecto` - Ecto integration for database-level authorization
  - `Permit.Phoenix` - Phoenix controller and LiveView integration
  """
  use Absinthe.Schema.Notation

  @doc """
  Adds Permit metadata to GraphQL types and fields.

  This macro allows you to specify:
  - The Ecto schema (or resource struct) that a GraphQL type maps to
  - The Permit action that a GraphQL field is authorized to perform
  - Custom ID parameter and field names for resource loading
  - Base query functions for custom filtering

  ## Options

  - `:schema` - The Ecto schema module that this GraphQL type represents
  - `:action` - The Permit action to authorize (required for mutations, defaults to `:read` for queries)
  - `:id_param_name` - The parameter name to use for resource lookup (defaults to `:id`)
  - `:id_struct_field_name` - The struct field name to match against (defaults to `:id`)
  - `:base_query` - A function to generate the base query for resource loading

  ## Examples

      # Map a GraphQL type to an Ecto schema
      object :article do
        permit schema: Blog.Content.Article

        field :id, :id
        field :title, :string
      end

      # Specify action for a field
      field :articles, list_of(:article) do
        permit action: :read
        resolve &load_and_authorize/2
      end

      # Custom ID parameter for slug-based lookup
      field :article_by_slug, :article do
        arg :slug, non_null(:string)
        permit action: :read, id_param_name: :slug, id_struct_field_name: :slug
        resolve &load_and_authorize/2
      end

      # Mutation with required action
      field :create_article, :article do
        permit action: :create
        arg :title, non_null(:string)
        resolve &ArticleResolver.create/3
      end
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
  Absinthe resolver that uses Dataloader for optimized batch loading with authorization.

  This resolver leverages Absinthe's Dataloader to efficiently batch database queries
  while still applying Permit authorization rules. It's particularly useful for resolving
  associations and preventing N+1 query problems in GraphQL.

  ## Parameters

  - `parent` - The parent object in the GraphQL resolution
  - `args` - The arguments passed to the field
  - `resolution` - The Absinthe resolution context

  ## Example

      field :posts, list_of(:post) do
        permit action: :read
        resolve &authorized_dataloader/3
      end

      field :comments, list_of(:comment) do
        permit action: :read
        resolve &authorized_dataloader/3
      end

  ## Setup

  To use this resolver, you need to configure Dataloader in your field:

      middleware(Permit.Absinthe.Middleware.DataloaderSetup)

  Also, as typical with Dataloader, you need to configure the dataloader in your Absinthe schema:

      def plugins do
        [Absinthe.Middleware.Dataloader | Absinthe.Plugin.defaults()]
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
