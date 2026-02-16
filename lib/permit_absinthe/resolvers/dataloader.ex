defmodule Permit.Absinthe.Resolvers.Dataloader do
  @moduledoc """
  This module contains the dataloader-based resolver function that performs authorization
  based on rules defined with Permit.
  """
  import Absinthe.Resolution.Helpers, only: [dataloader: 1]
  alias Permit.Absinthe.Schema.{Helpers, Meta}

  # I've been wrangling with dialyzer errors with this function,
  # in which it seemingly is triggered by calling the function returned by the original
  # Absinthe.Resolution.Helpers.dataloader/1 function call.
  # The argument specs are in line with what the function returned by the dataloader/1
  # helper expects.
  #
  # But since the original Absinthe.Resolution.Helpers.dataloader/1 function itself
  # ignores a dialyzer error, I feel totally okay to do it here, too - until Elixir
  # finally ditches the damn thing for good in favour of its own typing system.
  @dialyzer {:nowarn_function, authorized_dataloader: 3}
  @spec authorized_dataloader(
          Absinthe.Resolution.source(),
          Absinthe.Resolution.arguments(),
          Absinthe.Resolution.t()
        ) :: tuple()
  def authorized_dataloader(parent, args, resolution) do
    {resolution, source_key} = ensure_dataloader_setup(resolution)

    dataloader_fun = dataloader(source_key)
    dataloader_fun.(parent, args, resolution)
  end

  @doc false
  @spec ensure_dataloader_setup(Absinthe.Resolution.t()) :: {Absinthe.Resolution.t(), String.t()}
  def ensure_dataloader_setup(resolution) do
    field_name = resolution.definition.schema_node.identifier
    field_meta = Meta.get_field_meta_from_resolution(resolution, :permit) || []

    # Get configured authorization module and dataloader structure from resolution
    authorization_module = get_authorization_module(resolution, field_name)
    dataloader = get_dataloader(resolution)

    action = field_meta[:action] || Helpers.default_action(resolution)
    source_key = "#{inspect(authorization_module)}:#{field_name}:#{action}"
    lookup_key = "#{inspect(authorization_module)}:#{field_name}"

    # Fast path: no source creation if already registered.
    dataloader_source =
      build_or_get_dataloader_source(
        dataloader,
        source_key,
        authorization_module,
        action,
        resolution
      )

    source_keys =
      resolution.context
      |> Map.get(:permit_dataloader_source_keys, %{})
      |> Map.put(lookup_key, source_key)

    new_context =
      resolution.context
      |> Map.put(:loader, dataloader_source)
      |> Map.put(:permit_dataloader_source_keys, source_keys)

    {%{resolution | context: new_context}, source_key}
  end

  defp get_authorization_module(resolution, field_name) do
    # Fallback to type meta if field meta is not found; raise if neither is found
    Meta.get_field_meta_from_resolution(resolution, :authorization_module) ||
      Meta.get_type_meta_from_resolution(resolution, :authorization_module) ||
      raise """
      No authorization module configured for field: #{field_name}.
      Use permit(authorization_module: ...) to configure it.
      """
  end

  defp get_dataloader(resolution) do
    case resolution.context[:loader] do
      nil -> Dataloader.new(timeout: Dataloader.default_timeout())
      existing -> existing
    end
  end

  defp build_or_get_dataloader_source(
         dataloader,
         source_key,
         authorization_module,
         action,
         resolution
       ) do
    case dataloader do
      # Fast path: return existing source if it exists
      %{sources: sources} when is_map(sources) and is_map_key(sources, source_key) ->
        dataloader

      # Source not found yet: create new structure
      _ ->
        repo = authorization_module.repo()
        current_user = resolution.context[:current_user]

        source =
          Permit.Absinthe.Dataloader.new(repo, authorization_module, current_user, action)

        Dataloader.add_source(dataloader, source_key, source)
    end
  end
end
