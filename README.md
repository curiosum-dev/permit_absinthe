# PermitAbsinthe

PermitAbsinthe provides integration between the [Permit](https://hexdocs.pm/permit) authorization library and [Absinthe](https://hexdocs.pm/absinthe) GraphQL for Elixir.

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

## Usage

### Map GraphQL Types to Permit Resources

In your Absinthe schema, define metadata that maps your GraphQL types to Ecto schemas:

```elixir
object :post do
  meta :permit, schema: MyApp.Blog.Post

  field :id, :id
  field :title, :string
  field :content, :string
end
```

Alternatively, you can use the helper function (it's just syntactic sugar that does the same thing):

```elixir
import Permit.Absinthe

object :post do
  permit schema: MyApp.Blog.Post

  # fields...
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

PermitAbsinthe provides resolver functions to load and authorize resources automatically:

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
      resolve &load_and_authorize_one/3
    end

    field :posts, list_of(:post) do
      resolve &load_and_authorize_all/3
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
  resolve &load_and_authorize_one/3
end
```

### Custom Resolvers with Authorization

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

MIT

