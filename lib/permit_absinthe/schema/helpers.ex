defmodule Permit.Absinthe.Schema.Helpers do
  @moduledoc false
  alias Permit.Absinthe.Schema.Meta

  @doc """
  Checks if the current operation is a mutation.
  """
  def mutation?(resolution) do
    resolution.path
    |> Enum.any?(fn
      %Absinthe.Blueprint.Document.Operation{type: :mutation} -> true
      _ -> false
    end)
  end

  @doc """
  Returns the default action for a given resolution. If resolution is a mutation, it raises an error.
  """
  def default_action(resolution) do
    if mutation?(resolution) do
      raise ArgumentError,
            """
            Authorization action must be specified for mutations - e.g.: `permit action: :create`.
            For queries, `:read` is assumed by default.
            """
    else
      :read
    end
  end

  @doc """
  Returns a base query for a given resolution.

  If a custom base_query function is provided in field_meta, it will be used.
  Otherwise, falls back to the default behavior.
  """
  def base_query(
        %{
          resource_module: resource_module,
          resolution: resolution,
          params: params
        } = context
      ) do
    field_meta = Meta.get_field_meta_from_resolution(resolution, :permit)

    if is_function(field_meta[:base_query], 1) do
      field_meta[:base_query].(context)
    else
      default_base_query(resource_module, params, field_meta)
    end
  end

  defp default_base_query(resource_module, params, field_meta) do
    param = field_meta[:id_param_name] || :id
    field = field_meta[:id_struct_field_name] || :id

    case params do
      %{^param => id} ->
        resource_module
        |> Permit.Ecto.filter_by_field(field, id)

      _ ->
        Permit.Ecto.from(resource_module)
    end
  end
end
