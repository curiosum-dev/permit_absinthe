defmodule Permit.Absinthe.DirectiveHydrationTest do
  use ExUnit.Case

  # Test schema specifically for directive hydration testing
  defmodule TestSchema do
    use Absinthe.Schema

    use Permit.Absinthe,
      authorization_module: Permit.AbsintheFakeApp.Authorization,
      auto_load_and_authorize: true

    @prototype_schema Permit.Absinthe.Schema.Prototype

    # Simple types without custom resolvers
    object :simple_item do
      field(:id, :id)
      field(:name, :string)
    end

    # Queries - these should get the load_and_authorize directive automatically
    query do
      field :simple_item, :simple_item do
        arg(:id, non_null(:id))
      end

      field(:simple_items, list_of(:simple_item))
    end

    # Mutations - these should also get the directive
    mutation do
      field :create_simple_item, :simple_item do
        arg(:name, :string)
      end
    end
  end

  describe "directive hydration" do
    test "directives are successfully hydrated into schema with auto_load_and_authorize option" do
      # Test that the directive hydration is working by checking SDL output
      sdl = Absinthe.Schema.to_sdl(TestSchema)

      # Verify that our authorization phase successfully added directives
      assert String.contains?(sdl, "@loadAndAuthorize")

      # Check that query fields have the directive
      assert String.contains?(sdl, "simpleItem(id: ID!): SimpleItem @loadAndAuthorize")
      assert String.contains?(sdl, "simpleItems: [SimpleItem] @loadAndAuthorize")
    end

    test "directives are NOT hydrated into schema without auto_load_and_authorize" do
      # Test that schemas without the option don't get automatic directives
      sdl = Absinthe.Schema.to_sdl(Permit.AbsintheFakeApp.Schema)

      # This schema should NOT have automatic directives on all fields
      # It should only have directives where explicitly specified
      # This one has explicit directive
      assert String.contains?(sdl, "items: [Item] @loadAndAuthorize")

      # But query fields without explicit directives should not have them
      # This should NOT be auto-added
      refute String.contains?(sdl, "item(id: ID!): Item @loadAndAuthorize")
      # This should NOT be auto-added
      refute String.contains?(sdl, "user(id: ID!): User @loadAndAuthorize")
    end

    test "SDL export includes directive information" do
      # Test that when we export to SDL, we can see evidence of the directives
      sdl = Absinthe.Schema.to_sdl(TestSchema)

      # The SDL should show our hydrated directives on query and mutation fields
      assert String.contains?(sdl, "type RootQueryType")
      assert String.contains?(sdl, "type RootMutationType")

      # Check that directives are actually applied to fields
      assert String.contains?(sdl, "@loadAndAuthorize")

      # At minimum, the schema should be valid and exportable
      assert is_binary(sdl)
      assert String.length(sdl) > 0
    end
  end
end
