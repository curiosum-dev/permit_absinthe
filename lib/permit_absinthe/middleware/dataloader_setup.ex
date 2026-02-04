defmodule Permit.Absinthe.Middleware.DataloaderSetup do
  @moduledoc """
  Middleware that sets up authorization-aware dataloaders during GraphQL field resolution.

  The problem: traditional dataloader setup happens in the schema's `context/1` callback,
  before we know anything about field-specific authorization. This middleware fixes that
  by creating dataloaders on-demand with the right authorization context.

  Add it to top-level fields:

      field :me, :user do
        middleware Permit.Absinthe.Middleware.DataloaderSetup
        resolve &UserResolver.me/3
      end

  Then use the configured sources in nested resolvers:

      object :user do
        field :articles, list_of(:article) do
          resolve &Permit.Absinthe.Resolvers.Dataloader.authorized_dataloader/3
        end
      end

  Each dataloader source gets a unique key like `"MyApp.Auth:me:read"` so different
  authorization contexts don't step on each other.
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
