defmodule Permit.Absinthe.NestedTypeWrappersTest do
  # This verifies that nested type wrappers works correctly.
  # Fields with nested type wrappers like `non_null(list_of(:item))` must be detected as
  # `:all`-type actions. This tests recursive type unwrapping to correctly detect List
  # types at any nesting level.
  # Also, this addresses type metadata lookup for nested wrapped types.
  use ExUnit.Case, async: true

  alias Permit.Absinthe.Schema.Meta

  describe "get_type_name/1 - public API" do
    test "returns correct type for unwrapped type" do
      resolution = %{
        definition: %{
          schema_node: %{
            type: :item
          }
        }
      }

      result = Meta.get_type_name(resolution)
      assert result == :item
    end

    test "returns correct type for NonNull wrapped type" do
      resolution = %{
        definition: %{
          schema_node: %{
            type: %Absinthe.Type.NonNull{of_type: :item}
          }
        }
      }

      result = Meta.get_type_name(resolution)
      assert result == :item
    end

    test "returns correct type for List wrapped type" do
      resolution = %{
        definition: %{
          schema_node: %{
            type: %Absinthe.Type.List{of_type: :item}
          }
        }
      }

      result = Meta.get_type_name(resolution)
      assert result == :item
    end

    test "returns correct type for nested wrappers - non_null(list_of(...))" do
      resolution = %{
        definition: %{
          schema_node: %{
            type: %Absinthe.Type.NonNull{
              of_type: %Absinthe.Type.List{of_type: :item}
            }
          }
        }
      }

      result = Meta.get_type_name(resolution)
      assert result == :item
    end

    test "returns correct type for nested wrappers - list_of(non_null(...))" do
      resolution = %{
        definition: %{
          schema_node: %{
            type: %Absinthe.Type.List{
              of_type: %Absinthe.Type.NonNull{of_type: :item}
            }
          }
        }
      }

      result = Meta.get_type_name(resolution)
      assert result == :item
    end

    test "returns nil for invalid resolution" do
      result = Meta.get_type_name(%{})
      assert result == nil
    end

    test "returns nil for nil resolution" do
      result = Meta.get_type_name(nil)
      assert result == nil
    end
  end
end
