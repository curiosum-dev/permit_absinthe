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

    # Simple approach using Absinthe.run with context
    Absinthe.run(query, Schema, context: context, variables: variables)
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
  Gets a specific item by thread_name through a GraphQL query using custom ID parameters.
  """
  def get_item_by_thread_name(thread_name, current_user \\ nil) do
    query = """
    query GetItemByThreadName($threadName: String!) {
      itemByThreadName(thread_name: $threadName) {
        id
        permission_level
        thread_name
        owner_id
      }
    }
    """

    query_gql(query, current_user: current_user, variables: %{"threadName" => thread_name})
  end

  @doc """
  Gets a specific subitem by name through a GraphQL query using custom ID parameters.
  """
  def get_subitem_by_name(name, current_user \\ nil) do
    query = """
    query GetSubitemByName($name: String!) {
      subitemByName(name: $name) {
        id
        name
        item_id
      }
    }
    """

    query_gql(query, current_user: current_user, variables: %{"name" => name})
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
  Gets current user information with nested items via Dataloader.
  """
  def get_me(current_user) do
    query = """
    query GetMe {
      me {
        id
        items {
          id
          owner_id
          subitems {
            id
            item_id
            name
          }
        }
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
