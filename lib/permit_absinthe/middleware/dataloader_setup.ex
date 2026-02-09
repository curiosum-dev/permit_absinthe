defmodule Permit.Absinthe.Middleware.DataloaderSetup do
  @moduledoc """
  Middleware that sets up authorization-aware dataloaders during GraphQL field resolution.

  The problem: traditional dataloader setup happens in the schema's `context/1` callback,
  before we know anything about field-specific authorization. This middleware fixes that
  by creating dataloaders on-demand with the right authorization context.

  ## Usage

  Using the `Permit.Absinthe` mixin in your schema, the `authorized_dataloader/3` function
  is imported and available as the resolver function. The `Absinthe.Middleware.Dataloader`
  plugin must also be included.

  ```
  # Absinthe schema module
  defmodule MyAppWeb.Schema do
    use Permit.Absinthe, authorization_module: MyApp.Authorization

    def plugins do
      [Absinthe.Middleware.Dataloader | Absinthe.Plugin.defaults()]
    end
  end
  ```

  To use the authorization-aware dataloader resolver with an associated field, first
  add the middleware and a `permit` annotation to the field that resolves the parent
  type. Every field whose resolved type contains fields using `authorized_dataloader/3`
  must have this middleware attached.

      field :me, :user do
        permit action: :read
        middleware Permit.Absinthe.Middleware.DataloaderSetup
        resolve &UserResolver.me/3
      end

  Since the middleware we configured above only configures the authorization context,
  we now need to use an actual resolver function that leverages it.
  For this purpose, use the `authorized_dataloader/3` resolver on the associated
  object's fields.

  The object type itself needs a `permit(schema: ...)` annotation so the dataloader
  knows which Ecto schema to authorize against:

      object :user do
        permit schema: User

        field :articles, list_of(:article) do
          resolve &authorized_dataloader/3
        end
      end

  Each dataloader source gets a unique key like `"MyApp.Authorization:me:read"` so
  different authorization contexts don't step on each other. This prevents, for
  example, an `:admin` field's broader authorization scope from leaking into a `:me`
  field's restricted scope within the same request. Resolvers look up their source
  key dynamically via a lookup key like `"MyApp.Authorization:me"`, so the action in
  the source key reflects whatever was configured for the field.
  """

  @behaviour Absinthe.Middleware
  alias Permit.Absinthe.Schema.{Helpers, Meta}

  @impl true
  def call(resolution, _opts) do
    # Extract authorization info from resolution
    field_meta = Meta.get_field_meta_from_resolution(resolution, :permit)

    authorization_module = Meta.get_field_meta_from_resolution(resolution, :authorization_module)
    repo = authorization_module.repo()
    action = field_meta[:action] || Helpers.default_action(resolution)
    current_user = resolution.context[:current_user]

    # Create context-specific dataloader source
    source = Permit.Absinthe.Dataloader.new(repo, authorization_module, current_user, action)

    # Create or update dataloader in context
    dataloader =
      case resolution.context[:loader] do
        nil -> Dataloader.new(timeout: Dataloader.default_timeout())
        existing -> existing
      end

    # Add source with a unique key based on authorization params
    field_name = resolution.definition.schema_node.identifier
    source_key = "#{inspect(authorization_module)}:#{field_name}:#{action}"
    dataloader = Dataloader.add_source(dataloader, source_key, source)

    # Update context
    new_context = Map.put(resolution.context, :loader, dataloader)
    %{resolution | context: new_context}
  end
end
