defmodule Permit.AbsintheFakeAppTest do
  use ExUnit.Case

  alias Permit.AbsintheFakeApp.{Repo, Setup, TestHelpers}

  setup_all do
    # Setup the test database
    Setup.setup_test_db()
    :ok
  end

  setup do
    # Start a transaction for this test
    Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    # Seed test data
    %{users: users, items: items} = Repo.seed_data!()

    %{users: users, items: items}
  end

  describe "Fake App GraphQL" do
    test "can query an item with authorization", %{
      items: _items,
      users: [admin, owner, inspector]
    } do
      # Admin can read any item
      assert {:ok, result} = TestHelpers.get_item(1, admin)
      assert result.data["item"]["id"] == "1"

      # Owner can only read owned items
      assert {:ok, result} = TestHelpers.get_item(2, owner)
      assert result.data["item"]["id"] == "2"

      # Inspector can read any item
      assert {:ok, result} = TestHelpers.get_item(3, inspector)
      assert result.data["item"]["id"] == "3"
    end

    test "returns authorization error when user does not have access to item", %{
      users: [_admin, owner, _inspector]
    } do
      assert {:ok, result} = TestHelpers.get_item(3, owner)
      assert [%{message: "Unauthorized"}] = result.errors
    end

    test "returns not found error when item does not exist", %{
      users: [admin, _, _]
    } do
      assert {:ok, result} = TestHelpers.get_item(4, admin)
      assert [%{message: "Not found"}] = result.errors
    end

    test "loads and authorizes item via middleware", %{users: [admin, _, _]} do
      assert {:ok, result} =
               TestHelpers.update_item(%{id: 1, permission_level: 5, thread_name: "test"}, admin)

      assert %{"id" => "1", "owner_id" => "1", "permission_level" => 5, "thread_name" => "test"} =
               result.data["updateItem"]
    end

    test "returns authorization error when user does not have access to item via middleware", %{
      users: [_, owner, _]
    } do
      assert {:ok, result} =
               TestHelpers.update_item(%{id: 3, permission_level: 5, thread_name: "test"}, owner)

      assert [%{message: "Unauthorized"}] = result.errors
    end

    test "returns not found error when item does not exist via middleware", %{
      users: [admin, _, _]
    } do
      assert {:ok, result} =
               TestHelpers.update_item(%{id: 5, permission_level: 5, thread_name: "test"}, admin)

      assert [%{message: "Not found"}] = result.errors
    end

    test "authorization rules are enforced for GraphQL queries", %{
      users: [_admin, owner, _inspector]
    } do
      # Owner can only read owned items, and should be denied access to other items
      assert {:ok, result} = TestHelpers.get_item(1, owner)
      assert result.errors != nil

      # Owner should be able to access their own item
      assert {:ok, result} = TestHelpers.get_item(2, owner)
      assert result.data["item"]["id"] == "2"
    end
  end
end
