defmodule PermitAbsintheDemo.Actions do
  @moduledoc false
  use Permit.Actions

  @impl true
  def grouping_schema, do: crud_grouping()

  @impl true
  def singular_actions, do: crud_singular()
end
