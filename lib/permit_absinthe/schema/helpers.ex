defmodule Permit.Absinthe.Schema.Helpers do
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
  """
  def base_query(%{
        resource_module: resource_module,
        resolution: resolution,
        params: params
      }) do
    field_meta = Meta.get_field_meta_from_resolution(resolution, :permit)
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
