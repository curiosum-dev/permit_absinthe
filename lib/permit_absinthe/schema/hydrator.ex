defmodule Permit.Absinthe.Schema.Hydrator do
  @moduledoc false

  @behaviour Absinthe.Schema.Hydrator

  @impl true
  def apply_hydration(%{function_ref: {whatever, _}} = node, _)
      when whatever in [:query, :mutation] do
    %{node | directives: [:load_and_authorize | node.directives]}
  end

  def apply_hydration(node, _), do: node
end
