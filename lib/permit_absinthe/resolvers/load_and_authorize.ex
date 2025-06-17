defmodule Permit.Absinthe.Resolvers.LoadAndAuthorize do
  @moduledoc """
  Absinthe resolver that loads and authorizes a resource or list of resources.

  ## Examples

      # As a resolver function
      field :post, :post do
        arg :id, non_null(:id)
        resolve &load_and_authorize/2
      end

      # Resolver for a list of resources
      field :posts, list_of(:post) do
        resolve &load_and_authorize/2
      end
  """

  defdelegate load_and_authorize(args, resolution), to: Permit.Absinthe.LoadAndAuthorize
end
