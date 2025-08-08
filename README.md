# Permit.Absinthe

Permit.Absinthe provides integration between the [Permit](https://hexdocs.pm/permit) authorization library and [Absinthe](https://hexdocs.pm/absinthe) GraphQL for Elixir.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `permit_absinthe` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:permit_absinthe, "~> 0.1.0"}
  ]
end
```

Permit.Absinthe depends on [`:permit`](https://hex.pm/packages/permit) and [`permit_ecto`](https://hex.pm/packages/permit_ecto), as well as on Absinthe and Dataloader. It does not depend on Absinthe.Plug except for running tests.

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/permit_absinthe>.

## Features

- Map GraphQL types to Permit resource modules (Ecto schemas)
- Automatically check permissions for queries and mutations
- Resolvers for automatic resource loading and authorization

## Usage

### Map GraphQL types to Permit resources

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

### Add field-specific actions

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

### Using authorization resolvers

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
      permit action: :read
      arg :id, non_null(:id)
      resolve &load_and_authorize/2
    end

    field :posts, list_of(:post) do
      permit action: :read
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

### Load & authorize using Absinthe Middleware

In mutations, or whenever  custom and more complex resolution logic needs to be used, the `Permit.Absinthe.Middleware.LoadAndAuthorize` can be used, preloading the resource (or list of resources) into `context`, which then can be consumed in a custom Absinthe resolver function.

```elixir
  query do
    @desc "Get all articles"
    field :articles, list_of(:article) do
      permit action: :read

      middleware Permit.Absinthe.Middleware.LoadAndAuthorize

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

      middleware Permit.Absinthe.Middleware.LoadAndAuthorize

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

      middleware Permit.Absinthe.Middleware.LoadAndAuthorize

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

### Authorizing with GraphQL directives

Permit.Absinthe provides the `:load_and_authorize` directive to automatically load and authorize resources in your GraphQL fields.

The most reliable way to add Permit directives to your schema is using the prototype schema:

```elixir
defmodule MyAppWeb.Schema do
  use Absinthe.Schema

  @prototype_schema Permit.Absinthe.Schema.Prototype

  # Your schema definition...

  query do
    field :items, list_of(:item), directives: [:load_and_authorize] do
      permit(action: :read)

      resolve(fn _, %{context: %{loaded_resources: items}} ->
        {:ok, items}
      end)
    end
  end
end
```

The `:load_and_authorize` directive works with both single resources and lists of resources, ensuring that only accessible items are returned to the client based on the permission rules defined in your authorization module.

### Custom resolvers with vanilla Permit authorization

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

## License

MIT (see [LICENSE](./LICENSE)).
