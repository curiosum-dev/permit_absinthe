defmodule Permit.Absinthe.Resolvers.Dataloader do
  @moduledoc """
  This module contains the dataloader-based resolver function that performs authorization
  based on rules defined with Permit.
  """
  import Absinthe.Resolution.Helpers, only: [dataloader: 1]

  # I've been wrangling with a :no_return dialyzer error with this function,
  # in which it seemingly is triggered by calling the function returned by the original
  # Absinthe.Resolution.Helpers.dataloader/1 function call.
  # The argument specs are in line with what the function returned by the dataloader/1
  # helper expects.
  #
  # But since the original Absinthe.Resolution.Helpers.dataloader/1 function itself
  # ignores a dialyzer error, I feel totally okay to do it here, too - until Elixir
  # finally ditches the damn thing for good in favour of its own typing system.
  @dialyzer {:no_return, authorized_dataloader: 3}
  @spec authorized_dataloader(
          Absinthe.Resolution.source(),
          Absinthe.Resolution.arguments(),
          Absinthe.Resolution.t()
        ) :: tuple()
  def authorized_dataloader(parent, args, resolution) do
    parent_name = (resolution.path |> Enum.reverse() |> Enum.drop(1) |> List.first()).name

    authorization_module =
      Permit.Absinthe.Schema.Meta.get_type_meta_from_resolution(
        resolution,
        :authorization_module
      )

    dataloader_fun = dataloader("#{inspect(authorization_module)}:#{parent_name}:read")

    dataloader_fun.(parent, args, resolution)
  end
end
