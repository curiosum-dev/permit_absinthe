defmodule Permit.Absinthe.ConfigurableOptionsTest do
  @moduledoc """
  Tests for the new configurable options in permit macro.
  """
  use ExUnit.Case

  alias Permit.AbsintheFakeApp.{Item, Repo, Setup, User}

  @admin_user %User{id: 1, roles: ["admin"], permission_level: 100}
  @regular_user %User{id: 2, roles: ["user"], permission_level: 1}
  @custom_user %User{id: 3, roles: ["admin"], permission_level: 50}

  setup_all do
    Setup.setup_test_db()
    :ok
  end

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    user1 = %User{id: 1, roles: ["admin"], permission_level: 100}
    user2 = %User{id: 2, roles: ["user"], permission_level: 1}

    Repo.insert!(user1)
    Repo.insert!(user2)

    item1 = %Item{id: 1, permission_level: 1, thread_name: "test1", owner_id: 1}
    item2 = %Item{id: 2, permission_level: 50, thread_name: "test2", owner_id: 2}
    item3 = %Item{id: 3, permission_level: 100, thread_name: "test3", owner_id: 1}

    Repo.insert!(item1)
    Repo.insert!(item2)
    Repo.insert!(item3)

    :ok
  end

  describe "fetch_subject option" do
    test "uses custom fetch_subject function" do
      query = """
      query GetItem($id: ID!) {
        itemWithCustomSubject(id: $id) {
          id
          threadName
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "1"},
          context: %{custom_user: @custom_user}
        )

      assert {:ok, %{data: %{"itemWithCustomSubject" => item}}} = result
      assert item["id"] == "1"
    end

    test "returns error when custom fetch_subject returns nil" do
      query = """
      query GetItem($id: ID!) {
        itemWithCustomSubject(id: $id) {
          id
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "1"},
          context: %{}
        )

      assert {:ok, %{data: %{"itemWithCustomSubject" => nil}, errors: errors}} = result
      assert length(errors) > 0
    end

    test "handles fetch_subject that raises exception" do
      query = """
      query GetItem($id: ID!) {
        itemWithRaisingFetchSubject(id: $id) {
          id
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "1"},
          context: %{current_user: @admin_user}
        )

      assert {:ok, %{data: %{"itemWithRaisingFetchSubject" => nil}, errors: errors}} = result
      assert length(errors) > 0
    end

    test "works for list fields and prefers custom_user over current_user" do
      query = """
      query GetItems {
        itemsWithCustomSubject {
          id
        }
      }
      """

      assert {:ok, %{data: %{"itemsWithCustomSubject" => items}}} =
               Absinthe.run(
                 query,
                 Permit.AbsintheFakeApp.Schema,
                 context: %{custom_user: @custom_user}
               )

      assert length(items) == 3
    end

    test "returns unauthorized when fetch_subject yields nil for list field" do
      query = """
      query GetItems {
        itemsWithCustomSubject {
          id
        }
      }
      """

      assert {:ok, %{data: %{"itemsWithCustomSubject" => nil}, errors: errors}} =
               Absinthe.run(query, Permit.AbsintheFakeApp.Schema, context: %{})

      assert Enum.any?(errors, fn err -> err.message =~ "Unauthorized" end)
    end
  end

  describe "base_query option" do
    test "uses custom base_query for filtering" do
      query = """
      query GetItem($id: ID!, $ownerId: ID) {
        itemWithCustomBaseQuery(id: $id, ownerId: $ownerId) {
          id
          ownerId
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "1", "ownerId" => "1"},
          context: %{current_user: @admin_user}
        )

      assert {:ok, %{data: %{"itemWithCustomBaseQuery" => item}}} = result
      assert item["id"] == "1"
      assert item["ownerId"] == "1"
    end

    test "returns not found when base_query filters out the item" do
      query = """
      query GetItem($id: ID!, $ownerId: ID) {
        itemWithCustomBaseQuery(id: $id, ownerId: $ownerId) {
          id
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "1", "ownerId" => "999"},
          context: %{current_user: @admin_user}
        )

      assert {:ok, %{data: %{"itemWithCustomBaseQuery" => nil}, errors: errors}} = result
      assert Enum.any?(errors, fn err -> String.contains?(err.message, "Not found") end)
    end
  end

  describe "finalize_query option" do
    test "applies pagination with finalize_query" do
      query = """
      query GetItems($limit: Int, $offset: Int) {
        itemsWithFinalizeQuery(limit: $limit, offset: $offset) {
          id
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"limit" => 2, "offset" => 0},
          context: %{current_user: @admin_user}
        )

      assert {:ok, %{data: %{"itemsWithFinalizeQuery" => items}}} = result
      assert length(items) <= 2
    end

    test "works without pagination params" do
      query = """
      query GetItems {
        itemsWithFinalizeQuery {
          id
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          context: %{current_user: @admin_user}
        )

      assert {:ok, %{data: %{"itemsWithFinalizeQuery" => items}}} = result
      assert is_list(items)
    end

    test "finalize_query that filters everything returns empty list" do
      query = """
      query GetItems($limit: Int, $offset: Int) {
        itemsWithFinalizeQuery(limit: $limit, offset: $offset) {
          id
        }
      }
      """

      assert {:ok, %{data: %{"itemsWithFinalizeQuery" => items}}} =
               Absinthe.run(
                 query,
                 Permit.AbsintheFakeApp.Schema,
                 variables: %{"limit" => 0, "offset" => 0},
                 context: %{current_user: @admin_user}
               )

      assert items == []
    end
  end

  describe "handle_unauthorized option" do
    test "uses custom unauthorized handler" do
      query = """
      query GetItem($id: ID!) {
        itemWithCustomUnauthorized(id: $id) {
          id
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "3"},
          context: %{current_user: @regular_user}
        )

      assert {:ok, %{data: %{"itemWithCustomUnauthorized" => nil}, errors: errors}} = result

      error = List.first(errors)
      assert error.message =~ "Custom unauthorized"
      assert error.message =~ "Permit.AbsintheFakeApp.Item"
    end

    test "custom handler wins over unauthorized_message" do
      query = """
      query GetItem($id: ID!) {
        itemWithHandlerAndMessage(id: $id) {
          id
        }
      }
      """

      assert {:ok, %{data: %{"itemWithHandlerAndMessage" => nil}, errors: errors}} =
               Absinthe.run(
                 query,
                 Permit.AbsintheFakeApp.Schema,
                 variables: %{"id" => "1"},
                 context: %{}
               )

      assert Enum.any?(errors, fn err -> err.message =~ "Handler wins" end)
    end
  end

  describe "handle_not_found option" do
    test "uses custom not found handler" do
      query = """
      query GetItem($id: ID!) {
        itemWithCustomNotFound(id: $id) {
          id
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "999"},
          context: %{current_user: @admin_user}
        )

      assert {:ok, %{data: %{"itemWithCustomNotFound" => nil}, errors: errors}} = result

      error = List.first(errors)
      assert error.message =~ "Custom not found"
    end
  end

  describe "unauthorized_message option" do
    test "uses custom unauthorized message" do
      query = """
      query GetItem($id: ID!) {
        itemWithCustomMessage(id: $id) {
          id
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "3"},
          context: %{current_user: @regular_user}
        )

      assert {:ok, %{data: %{"itemWithCustomMessage" => nil}, errors: errors}} = result

      error = List.first(errors)
      assert error.message == "You don't have permission to view this item"
    end
  end

  describe "loader option" do
    test "uses custom loader instead of Ecto" do
      query = """
      query GetItem($id: ID!) {
        itemWithCustomLoader(id: $id) {
          id
          threadName
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "1"},
          context: %{current_user: @admin_user}
        )

      assert {:ok, %{data: %{"itemWithCustomLoader" => item}}} = result
      assert item["threadName"] == "custom_loaded"
    end

    test "custom loader still respects authorization" do
      query = """
      query GetItem($id: ID!) {
        itemWithCustomLoader(id: $id) {
          id
          threadName
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "1"},
          context: %{current_user: @admin_user}
        )

      assert {:ok, %{data: %{"itemWithCustomLoader" => item}}} = result
      assert item["threadName"] == "custom_loaded"
    end

    test "custom loader denies access when no user is provided" do
      query = """
      query GetItem($id: ID!) {
        itemWithCustomLoader(id: $id) {
          id
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "1"},
          context: %{}
        )

      assert {:ok, %{data: %{"itemWithCustomLoader" => nil}, errors: errors}} = result
      assert length(errors) > 0
    end

    test "custom loader denies access to regular user without permission" do
      query = """
      query GetItem($id: ID!) {
        itemWithCustomLoader(id: $id) {
          id
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "1"},
          context: %{current_user: @regular_user}
        )

      assert {:ok, %{data: %{"itemWithCustomLoader" => nil}, errors: errors}} = result
      assert length(errors) > 0
    end

    test "loader that returns nil results in not_found error" do
      query = """
      query GetItem($id: ID!) {
        itemWithNilLoader(id: $id) {
          id
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "1"},
          context: %{current_user: @admin_user}
        )

      assert {:ok, %{data: %{"itemWithNilLoader" => nil}, errors: errors}} = result
      assert length(errors) > 0
      assert Enum.any?(errors, fn err -> err.message =~ "Not found" end)
    end

    test "loader function that raises exception is handled gracefully" do
      query = """
      query GetItem($id: ID!) {
        itemWithRaisingLoader(id: $id) {
          id
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "1"},
          context: %{current_user: @admin_user}
        )

      assert {:ok, %{data: %{"itemWithRaisingLoader" => nil}, errors: errors}} = result
      assert length(errors) > 0
    end

    test "local function capture loader works without schema module qualification" do
      query = """
      query GetItems($ownerId: ID!) {
        itemsWithLocalCaptureLoader(ownerId: $ownerId) {
          id
          ownerId
          threadName
        }
      }
      """

      assert {:ok, %{data: %{"itemsWithLocalCaptureLoader" => items}}} =
               Absinthe.run(
                 query,
                 Permit.AbsintheFakeApp.Schema,
                 variables: %{"ownerId" => "1"},
                 context: %{current_user: @admin_user}
               )

      assert is_list(items)
      assert Enum.any?(items, &(&1["threadName"] == "external_1"))
    end

    test "custom loader can return a list and filters authorized items" do
      query = """
      query GetItems {
        itemsWithCustomLoader {
          id
          ownerId
        }
      }
      """

      assert {:ok, %{data: %{"itemsWithCustomLoader" => items}}} =
               Absinthe.run(
                 query,
                 Permit.AbsintheFakeApp.Schema,
                 context: %{current_user: @admin_user}
               )

      assert Enum.sort(Enum.map(items, & &1["id"])) == ["101", "102", "103"]

      owner_user = %User{id: 2, roles: ["owner"], permission_level: 1}

      assert {:ok, %{data: %{"itemsWithCustomLoader" => owner_items}}} =
               Absinthe.run(
                 query,
                 Permit.AbsintheFakeApp.Schema,
                 context: %{current_user: owner_user}
               )

      assert Enum.map(owner_items, & &1["id"]) == ["102"]
    end

    test "loader that returns nil for list field triggers not_found" do
      query = """
      query GetItems {
        itemsWithNilLoader {
          id
        }
      }
      """

      assert {:ok, %{data: %{"itemsWithNilLoader" => nil}, errors: errors}} =
               Absinthe.run(query, Permit.AbsintheFakeApp.Schema,
                 context: %{current_user: @admin_user}
               )

      assert Enum.any?(errors, fn err -> err.message =~ "Not found" end)
    end

    test "loader that returns empty list for single field returns not_found" do
      query = """
      query GetItem {
        itemWithEmptyListLoader {
          id
        }
      }
      """

      assert {:ok, %{data: %{"itemWithEmptyListLoader" => nil}, errors: errors}} =
               Absinthe.run(query, Permit.AbsintheFakeApp.Schema,
                 context: %{current_user: @admin_user}
               )

      assert Enum.any?(errors, fn err -> err.message =~ "Not found" end)
    end

    test "inline loader can call local helper function in schema module" do
      query = """
      query GetItems($ownerId: ID!) {
        itemsWithLocalHelperLoader(ownerId: $ownerId) {
          id
          ownerId
          threadName
        }
      }
      """

      assert {:ok, %{data: %{"itemsWithLocalHelperLoader" => items}}} =
               Absinthe.run(
                 query,
                 Permit.AbsintheFakeApp.Schema,
                 variables: %{"ownerId" => "2"},
                 context: %{current_user: @admin_user}
               )

      assert Enum.map(items, & &1["id"]) == ["901", "902"]
      assert Enum.uniq(Enum.map(items, & &1["ownerId"])) == ["2"]
    end
  end

  describe "wrap_authorized option" do
    test "wraps successful response" do
      query = """
      query GetItem($id: ID!) {
        itemWithWrappedResponse(id: $id) {
          id
          threadName
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "1"},
          context: %{current_user: @admin_user}
        )

      assert {:ok, %{data: %{"itemWithWrappedResponse" => item}}} = result
      assert item["id"] == "1"
    end

    test "wrap_authorized with error tuple is passed through" do
      query = """
      query GetItem($id: ID!) {
        itemWithErrorWrap(id: $id) {
          id
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "1"},
          context: %{current_user: @admin_user}
        )

      assert {:ok, %{data: %{"itemWithErrorWrap" => nil}, errors: errors}} = result
      assert length(errors) > 0
      assert Enum.any?(errors, fn err -> err.message =~ "Custom error from wrap" end)
    end

    test "handles wrap_authorized that raises exception" do
      query = """
      query GetItem($id: ID!) {
        itemWithRaisingWrapAuthorized(id: $id) {
          id
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "1"},
          context: %{current_user: @admin_user}
        )

      assert {:ok, %{data: %{"itemWithRaisingWrapAuthorized" => nil}, errors: errors}} = result
      assert length(errors) > 0

      assert Enum.any?(errors, fn err ->
               err.message =~ "wrap_authorized function raised an exception"
             end)
    end

    test "handles wrap_authorized with invalid string return type" do
      query = """
      query GetItem($id: ID!) {
        itemWithInvalidWrapReturn(id: $id) {
          id
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "1"},
          context: %{current_user: @admin_user}
        )

      assert {:ok, %{data: %{"itemWithInvalidWrapReturn" => nil}, errors: errors}} = result
      assert length(errors) > 0

      assert Enum.any?(errors, fn err ->
               err.message =~ "wrap_authorized function returned invalid type"
             end)
    end

    test "handles wrap_authorized with invalid tuple return type" do
      query = """
      query GetItem($id: ID!) {
        itemWithInvalidWrapReturnTuple(id: $id) {
          id
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "1"},
          context: %{current_user: @admin_user}
        )

      assert {:ok, %{data: %{"itemWithInvalidWrapReturnTuple" => nil}, errors: errors}} = result
      assert length(errors) > 0

      assert Enum.any?(errors, fn err ->
               err.message =~ "wrap_authorized function returned invalid type"
             end)
    end

    test "wrap_authorized runs on list fields" do
      query = """
      query GetItems {
        itemsWithWrappedResponse {
          id
        }
      }
      """

      assert {:ok, %{data: %{"itemsWithWrappedResponse" => items}}} =
               Absinthe.run(
                 query,
                 Permit.AbsintheFakeApp.Schema,
                 context: %{current_user: @admin_user}
               )

      assert Enum.map(items, & &1["id"]) == ["202", "201"]
    end
  end

  describe "handle_unauthorized option - error handling" do
    test "handles handle_unauthorized that raises exception" do
      query = """
      query GetItem($id: ID!) {
        itemWithRaisingUnauthorizedHandler(id: $id) {
          id
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "1"},
          context: %{}
        )

      assert {:ok, %{data: %{"itemWithRaisingUnauthorizedHandler" => nil}, errors: errors}} =
               result

      assert length(errors) > 0
      assert Enum.any?(errors, fn err -> err.message =~ "Unauthorized" end)
    end
  end

  describe "handle_not_found option - error handling" do
    test "handles handle_not_found that raises exception" do
      query = """
      query GetItem($id: ID!) {
        itemWithRaisingNotFoundHandler(id: $id) {
          id
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "1"},
          context: %{current_user: @admin_user}
        )

      assert {:ok, %{data: %{"itemWithRaisingNotFoundHandler" => nil}, errors: errors}} = result
      assert length(errors) > 0
      assert Enum.any?(errors, fn err -> err.message =~ "Not found" end)
    end
  end

  describe "combined options" do
    test "multiple options work together" do
      query = """
      query GetItem($id: ID!, $ownerId: ID) {
        itemWithCombinedOptions(id: $id, ownerId: $ownerId) {
          id
          ownerId
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "1", "ownerId" => "1"},
          context: %{custom_user: @custom_user}
        )

      assert {:ok, %{data: %{"itemWithCombinedOptions" => item}}} = result
      assert item["id"] == "1"
    end

    test "combined options: custom unauthorized takes precedence over message" do
      query = """
      query GetItem($id: ID!, $ownerId: ID) {
        itemWithCombinedOptions(id: $id, ownerId: $ownerId) {
          id
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "1"},
          context: %{}
        )

      assert {:ok, %{data: %{"itemWithCombinedOptions" => nil}, errors: errors}} = result

      error = List.first(errors)
      assert error.message == "Combined options: unauthorized"
    end
  end

  describe "mutation with custom options" do
    test "uses custom handle_unauthorized when user is unauthorized" do
      mutation = """
      mutation CreateItem($permissionLevel: Int, $threadName: String) {
        createItemWithCustomOptions(permissionLevel: $permissionLevel, threadName: $threadName) {
          id
        }
      }
      """

      unauthorized_user = %User{id: 999, roles: [], permission_level: 0}

      result =
        Absinthe.run(
          mutation,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"permissionLevel" => 1, "threadName" => "test"},
          context: %{current_user: unauthorized_user}
        )

      assert {:ok, %{data: %{"createItemWithCustomOptions" => nil}, errors: errors}} = result
      assert length(errors) > 0

      error = List.first(errors)
      assert error.message =~ "Cannot create item"
    end
  end

  describe "backwards compatibility" do
    test "fields without new options still work" do
      query = """
      query GetItem($id: ID!) {
        item(id: $id) {
          id
          threadName
        }
      }
      """

      result =
        Absinthe.run(
          query,
          Permit.AbsintheFakeApp.Schema,
          variables: %{"id" => "1"},
          context: %{current_user: @admin_user}
        )

      assert {:ok, %{data: %{"item" => item}}} = result
      assert item["id"] == "1"
    end
  end
end
