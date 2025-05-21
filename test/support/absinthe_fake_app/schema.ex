defmodule Permit.AbsintheFakeApp.Schema do
  use Absinthe.Schema
  use Permit.Absinthe, authorization_module: Permit.AbsintheFakeApp.Authorization

  alias Permit.AbsintheFakeApp.{Item, User}
  alias Permit.Absinthe, as: PermitAbsinthe

  # Custom types
  object :user do
    field(:id, :id)
    field(:roles, list_of(:string))
    field(:permission_level, :integer)

    permit(schema: User)
  end

  object :item do
    field(:id, :id)
    field(:permission_level, :integer)
    field(:thread_name, :string)
    field(:owner_id, :id)

    permit(schema: Item)
  end

  # Queries
  query do
    field :item, :item do
      arg(:id, non_null(:id))

      permit(action: :read)

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :items, list_of(:item) do
      permit(action: :read)

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :user, :user do
      arg(:id, non_null(:id))

      permit(action: :read)

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end
  end

  # Mutations
  mutation do
    field :create_item, :item do
      arg(:permission_level, :integer)
      arg(:thread_name, :string)
      arg(:owner_id, :id)

      permit(action: :create)

      resolve(fn args, %{context: %{current_user: current_user}} ->
        new_item = %Item{
          permission_level: args.permission_level,
          thread_name: args.thread_name,
          owner_id: args.owner_id || current_user.id
        }

        # We would normally insert the item here, but for testing
        # we'll just return it without database interaction
        {:ok, new_item}
      end)
    end

    field :update_item, :item do
      arg(:id, non_null(:id))
      arg(:permission_level, :integer)
      arg(:thread_name, :string)

      permit(action: :update)

      middleware(Permit.Absinthe.Middleware.LoadAndAuthorize)

      resolve(fn _,
                 %{permission_level: permission_level, thread_name: thread_name},
                 %{context: %{loaded_resource: item}} ->
        {:ok, %{item | permission_level: permission_level, thread_name: thread_name}}
      end)
    end
  end
end
