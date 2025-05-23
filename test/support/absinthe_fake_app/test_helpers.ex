defmodule Permit.AbsintheFakeApp.TestHelpers do
  @moduledoc """
  Helpers for testing GraphQL queries with Absinthe.
  """
  alias Permit.AbsintheFakeApp.Schema

  @doc """
  Simulates a GraphQL query execution with Absinthe.

  ## Options
    * `:current_user` - The current user context (default: nil)
    * `:variables` - GraphQL variables to be used in the query (default: %{})
  """
  def query_gql(query, options \\ []) do
    current_user = Keyword.get(options, :current_user)
    variables = Keyword.get(options, :variables, %{})

    context =
      case current_user do
        nil -> %{}
        user -> %{current_user: user}
      end

    Absinthe.run(
      query,
      Schema,
      variables: variables,
      context: context
    )
  end

  @doc """
  Gets a specific item by ID through a GraphQL query.
  """
  def get_item(id, current_user \\ nil) do
    query = """
    query GetItem($id: ID!) {
      item(id: $id) {
        id
        permission_level
        thread_name
        owner_id
      }
    }
    """

    query_gql(query, current_user: current_user, variables: %{"id" => id})
  end

  @doc """
  Gets all items through a GraphQL query.
  """
  def get_items(current_user \\ nil) do
    query = """
    query GetItems {
      items {
        id
        permission_level
        thread_name
        owner_id
      }
    }
    """

    query_gql(query, current_user: current_user)
  end

  @doc """
  Creates a new item through a GraphQL mutation.
  """
  def create_item(attrs, current_user \\ nil) do
    mutation = """
    mutation CreateItem($permissionLevel: Int, $threadName: String, $ownerId: ID) {
      createItem(permission_level: $permissionLevel, thread_name: $threadName, owner_id: $ownerId) {
        id
        permission_level
        thread_name
        owner_id
      }
    }
    """

    variables = %{
      "permissionLevel" => attrs[:permission_level],
      "threadName" => attrs[:thread_name],
      "ownerId" => attrs[:owner_id]
    }

    query_gql(mutation, current_user: current_user, variables: variables)
  end

  def update_item(attrs, current_user \\ nil) do
    mutation = """
    mutation UpdateItem($id: ID!, $permissionLevel: Int, $threadName: String) {
      updateItem(id: $id, permission_level: $permissionLevel, thread_name: $threadName) {
        id
        permission_level
        thread_name
        owner_id
      }
    }
    """

    variables = %{
      "id" => attrs[:id],
      "permissionLevel" => attrs[:permission_level],
      "threadName" => attrs[:thread_name]
    }

    query_gql(mutation, current_user: current_user, variables: variables)
  end
end
