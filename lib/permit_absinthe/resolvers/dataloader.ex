defmodule Permit.Absinthe.Resolvers.Dataloader do
  import Absinthe.Resolution.Helpers, only: [dataloader: 1]

  def authorized_dataloader(parent, args, resolution) do
    parent_name = (resolution.path |> Enum.reverse() |> Enum.drop(1) |> List.first()).name

    authorization_module =
      Permit.Absinthe.Schema.Meta.get_type_meta_from_resolution(
        resolution,
        :authorization_module
      )

    dataloader("#{inspect(authorization_module)}:#{parent_name}:read").(parent, args, resolution)
  end
end
