defmodule Permit.Absinthe.Schema.Hydrator do
  @moduledoc false

  @behaviour Absinthe.Schema.Hydrator

  @impl true
  def apply_hydration(
        %Absinthe.Blueprint.Schema.FieldDefinition{} = node,
        [%Absinthe.Blueprint.Schema.ObjectTypeDefinition{identifier: parent_identifier} | _]
      )
      when parent_identifier in [:query, :mutation] do
    # Only add the directive if it doesn't already exist
    if Enum.any?(node.directives, fn
         %{name: "load_and_authorize"} -> true
         %{identifier: :load_and_authorize} -> true
         :load_and_authorize -> true
         _ -> false
       end) do
      node
    else
      %{node | directives: [:load_and_authorize | node.directives]}
    end
  end

  def apply_hydration(node, _), do: node
end
