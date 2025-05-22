defmodule Permit.Absinthe.Schema.AuthorizationPhase do
  alias Absinthe.{Phase, Pipeline, Blueprint}

  def pipeline(pipeline) do
    Pipeline.insert_before(pipeline, Phase.Schema.Directives, __MODULE__)
  end

  def run(blueprint, _) do
    {:ok, blueprint}
  end
end
