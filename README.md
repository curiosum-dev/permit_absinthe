# Permit.Absinthe

Permit.Absinthe provides integration between the [Permit](https://hexdocs.pm/permit) authorization library and [Absinthe](https://hexdocs.pm/absinthe) GraphQL for Elixir.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `permit_absinthe` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:permit_absinthe, "~> 0.1.0"},
    {:permit, "~> 0.2.0"},
    {:permit_ecto, "~> 0.2.0"} # Optional, for Ecto integration
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/permit_absinthe>.

## Features

- Map GraphQL types to Permit resource modules (Ecto schemas)
- Automatically check permissions for queries and mutations
- Resolvers for automatic resource loading and authorization
- Authorization middleware for GraphQL fields
- Load and authorize directives
- **Optional automatic directive hydration** - automatically add authorization directives to all query/mutation fields

## Usage

### Map GraphQL Types to Permit Resources

In your Absinthe schema, define metadata that maps your GraphQL types to Ecto schemas:

```elixir
use Permit.Absinthe, authorization_module: MyApp.Authorization

object :post do
  # Equivalent under the hood to:
  #
  #   meta permit: [schema: MyApp.Blog.Post], authorization_module: MyApp.Authorization
  #
  permit schema: MyApp.Blog.Post

  field :id, :id
  field :title, :string
  field :content, :string
end
```

### Add Field-specific Actions

By default, queries map to the `:read` action while mutations require explicit actions. You can specify these using the `permit` macro (or `meta` likewise):

```elixir
field :unpublished_posts, list_of(:post) do
  permit action: :view_unpublished
  resolve &PostResolver.unpublished_posts/3
end

field :create_post, :post do
  permit action: :create
  resolve &PostResolver.create_post/3
end
```

### Using Authorization Resolvers

Permit.Absinthe provides resolver functions to load and authorize resources automatically:

```elixir
defmodule MyApp.Schema do
  use Absinthe.Schema
  use Permit.Absinthe, authorization_module: MyApp.Authorization

  object :post do
    permit schema: MyApp.Blog.Post

    field :id, :id
    field :title, :string
    field :content, :string
  end

  query do
    field :post, :post do
      arg :id, non_null(:id)
      resolve &load_and_authorize/2
    end

    field :posts, list_of(:post) do
      resolve &load_and_authorize/2
    end
  end

  # ...
end
```

Custom id field names and parameters can be specified:

```elixir
field :post_by_slug, :post do
  arg :slug, non_null(:string)
  permit action: :read, id_param_name: :slug, id_struct_field_name: :slug
  resolve &load_and_authorize/2
end
```

### Load & Authorize Using Middleware

In mutations, or whenever  custom and more complex resolution logic needs to be used, the `Permit.Absinthe.Middleware.LoadAndAuthorize` can be used, preloading the resource (or list of resources) into `context`, which then can be consumed in a custom Absinthe resolver function.

```elixir
  query do
    @desc "Get all articles"
    field :articles, list_of(:article) do
      permit action: :read

      middleware Permit.Absinthe.Middleware.LoadAndAuthorize, :all

      resolve(fn _parent, _args, %{context: context} = _resolution ->
        # ...
        {:ok, context.loaded_resources}
      end)

      # This would be equivalent:
      #
      # resolve &load_and_authorize/2
    end

    @desc "Get a specific article by ID"
    field :article, :article do
      permit action: :read

      middleware Permit.Absinthe.Middleware.LoadAndAuthorize, :one

      arg :id, non_null(:id)

      resolve(fn _parent, _args, %{context: context} = _resolution ->
        {:ok, context.loaded_resource}
      end)

      # This would be equivalent:
      #
      # resolve &load_and_authorize/2
    end
  end

  mutation do
    @desc "Update an article"
    field :update_article, :article do
      permit action: :update

      arg(:id, non_null(:id))
      arg(:name, non_null(:string))
      arg(:content, non_null(:string))

      middleware Permit.Absinthe.Middleware.LoadAndAuthorize, :one

      resolve(fn _, %{name: name, content: content}, %{context: context} ->
        case Blog.Content.update_article(context.loaded_resource, %{name: name, content: content}) do
          {:ok, article} ->
            {:ok, article}

          {:error, changeset} ->
            {:error, "Could not update article: #{inspect(changeset)}"}
        end
      end)
    end
  end
```

### Using the Authorize Directive

Permit.Absinthe provides an `:load_and_authorize` directive that can be used directly in your GraphQL schema to load and authorize resources at the field level. This approach is useful when you want declarative authorization rules applied to your queries:

```elixir
object :query do
  field :items, list_of(:item) do
    permit action: :read

    # The authorize directive will automatically check permissions
    # for the current user on each returned item
    directive :load_and_authorize

    resolve(fn _, %{context: %{loaded_resources: items}} ->
      {:ok, items}
    end)
  end
end
```

The `:load_and_authorize` directive works with both single resources and lists of resources, ensuring that only accessible items are returned to the client based on the permission rules defined in your authorization module.

### Custom Resolvers with Vanilla Permit Authorization

For more complex authorization scenarios, you can implement custom resolvers using vanilla Permit syntax:

```elixir
defmodule MyApp.Resolvers.Post do
  import MyApp.Authorization

  def create_post(_, args, %{context: %{current_user: user}} = _resolution) do
    if can(user) |> create?(MyApp.Post) do
      {:ok, MyApp.Blog.create_post(args)}
    else
      {:error, "Unauthorized"}
    end
  end
end
```

## Optional Directive Hydration

You can enable automatic directive hydration to add `@loadAndAuthorize` directives to all root query and mutation fields automatically:

```elixir
defmodule MyApp.Schema do
  use Absinthe.Schema
  use Permit.Absinthe,
    authorization_module: MyApp.Authorization,
    auto_load_and_authorize: true

  query do
    # These fields will automatically get @loadAndAuthorize directives
    field :users, list_of(:user)
    field :user, :user do
      arg :id, non_null(:id)
    end
  end

  mutation do
    # This field will also automatically get the directive
    field :create_user, :user do
      arg :name, :string
    end
  end
end
```

### Benefits

- **Opt-in**: Only schemas with `auto_load_and_authorize: true` are affected
- **Safe**: Won't add directives to fields that already have them or explicit middleware
- **Selective**: Only affects root query/mutation fields, not nested object type fields
- **Backward compatible**: Existing schemas without the option continue to work unchanged

### How it works

When you export your schema to SDL, you'll see:

```graphql
type RootQueryType {
  users: [User] @loadAndAuthorize
  user(id: ID!): User @loadAndAuthorize
}

type RootMutationType {
  createUser(name: String): User @loadAndAuthorize
}

type User {
  id: ID
  name: String
}
```

Notice that only the root query/mutation fields get the `@loadAndAuthorize` directive automatically. Object type fields like `User.id` and `User.name` are left unchanged.

## License

MIT

