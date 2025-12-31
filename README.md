<div align="center">
  <img src="https://github.com/user-attachments/assets/f0352656-397d-4d90-999a-d3adbae1095f">

  # Permit.Absinthe
  <p><strong>Authorization-aware GraphQL with Absinthe and Permit for Elixir.</strong></p>

  [![Contact Us](https://img.shields.io/badge/Contact%20Us-%23F36D2E?style=for-the-badge&logo=maildotru&logoColor=white&labelColor=F36D2E)](https://curiosum.com/contact)
  [![Visit Curiosum](https://img.shields.io/badge/Visit%20Curiosum-%236819E6?style=for-the-badge&logo=elixir&logoColor=white&labelColor=6819E6)](https://curiosum.com/services/elixir-software-development)
  [![License: MIT](https://img.shields.io/badge/License-MIT-1D0642?style=for-the-badge&logo=open-source-initiative&logoColor=white&labelColor=1D0642)]()
</div>

<br/>

Permit.Absinthe provides integration between the [Permit](https://hexdocs.pm/permit) authorization library and [Absinthe](https://hexdocs.pm/absinthe) GraphQL for Elixir.

[![Hex version badge](https://img.shields.io/hexpm/v/permit_absinthe.svg)](https://hex.pm/packages/permit_absinthe)
[![Version badge](https://img.shields.io/badge/Version-0.1.0-blue.svg)](https://github.com/curiosum-dev/permit_absinthe)
[![Actions Status](https://github.com/curiosum-dev/permit_absinthe/actions/workflows/elixir.yml/badge.svg)](https://github.com/curiosum-dev/permit_absinthe/actions)
[![License badge](https://img.shields.io/hexpm/l/permit.svg)](https://github.com/curiosum-dev/permit_absinthe/blob/master/LICENSE)

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

### Customisation options

The `permit` macro supports a set of options that let you customize how Permit Absinthe loads data, scopes Ecto queries, and formats success/errors.

- **`:fetch_subject`**: function to fetch the “subject” (usually current user) from the resolution context (defaults to `resolution.context[:current_user]`).
- **`:base_query`**: function to build a custom Ecto base query *before* Permit scoping is applied (useful for soft deletes / tenancy / additional filters).
- **`:finalize_query`**: function to post-process the Ecto query *after* Permit scoping is applied (useful for sorting / pagination).
- **`:handle_unauthorized`**: function called when authorization fails or when the subject is missing; should return `{:error, message}` (or `{:ok, value}` if you intentionally want to return a safe fallback).
- **`:handle_not_found`**: function called when the resource cannot be found; should return `{:error, message}`.
- **`:unauthorized_message`**: custom string message used on unauthorized access (only when `:handle_unauthorized` is not set).
- **`:loader`**: function to load data from a custom source (external API, cache, etc.) instead of the default Ecto/Dataloader-based loading.
- **`:wrap_authorized`**: function called on successful authorization; should return `{:ok, value}` (or `{:error, message}`) to reshape/redact the returned data.

#### Important caveat about callbacks

Permit Absinthe captures callback functions passed to `permit` (for example `permit loader: &external_notes_loader/1`) as AST at compile time to avoid Absinthe boilerplate. References, function calls, and aliases are supported, but **functions defined in your schema module must be public** (use `def`, not `defp`).

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

## Community & support

- **Issues**: [GitHub Issues](https://github.com/curiosum-dev/permit_absinthe/issues)
- **Elixir Slack**: Join us in [#permit](https://elixir-lang.slack.com/archives/C091Q5S0GDU) on Elixir Slack
- **Blog**: Permit-related content in the [Curiosum Blog](https://curiosum.com/blog?search=permit)

## Contributing

We welcome contributions! Please see the main [Permit Contributing Guide](https://github.com/curiosum-dev/permit/blob/master/CONTRIBUTING.md) for details.

Feel free to submit bugfix requests and feature ideas in Permit.Absinthe's [GitHub Issues](https://github.com/curiosum-dev/permit_absinthe/issues) and create pull requests, whereas the best place to discuss development ideas and questions is the [Permit channel in the Elixir Slack](https://elixir-lang.slack.com/archives/C091Q5S0GDU).

### Development setup

* Clone the repository and install dependencies with `mix deps.get` normally
* Tools such as Credo and Dialyzer should be run with `MIX_ENV=test`
* The test suite requires Postgres to run and configured as in `config/test.exs`

## Contact

* Library maintainer: [Michał Buszkiewicz](https://github.com/vincentvanbush)
* [**Curiosum**](https://curiosum.com) - Elixir development team behind Permit

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
