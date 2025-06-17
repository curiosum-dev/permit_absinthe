defmodule Permit.Absinthe.Resolvers.Dataloader do
  import Absinthe.Resolution.Helpers, only: [dataloader: 1]

  def authorized_dataloader(parent, args, resolution) do
    parent_name = (resolution.path |> Enum.reverse() |> Enum.drop(1) |> List.first()).name

    dataloader("Blog.Authorization:#{parent_name}:read").(parent, args, resolution)
  end
end
