defmodule Permit.Absinthe.Schema.Helpers do
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
end
