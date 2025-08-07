defmodule Permit.Absinthe.Dataloader do
  @moduledoc false
  import Ecto.Query

  @spec new(
          module(),
          Permit.Types.authorization_module(),
          Permit.Types.subject(),
          Permit.Types.action_group()
        ) :: Dataloader.Ecto.t()
  def new(repo, authorization_module, subject, action) do
    Dataloader.Ecto.new(repo,
      query: fn queryable, _params ->
        # Fix this in Permit.Ecto so this case is not needed
        case authorization_module.accessible_by!(subject, action, queryable) do
          %Ecto.Query.DynamicExpr{} = expr ->
            from(q in queryable, where: ^expr)

          query ->
            query
        end
      end
    )
  end
end
