defmodule Permit.AbsintheFakeApp.Schema do
  @moduledoc false
  use Absinthe.Schema
  use Permit.Absinthe, authorization_module: Permit.AbsintheFakeApp.Authorization

  @prototype_schema Permit.Absinthe.Schema.Prototype

  alias Permit.Absinthe, as: PermitAbsinthe
  alias Permit.AbsintheFakeApp.{Item, Subitem, User}

  # Custom types
  object :user do
    field(:id, :id)
    field(:roles, list_of(:string))
    field(:permission_level, :integer)

    field(:items, list_of(:item), resolve: &authorized_dataloader/3)

    permit(schema: User)
  end

  object :subitem do
    field(:id, :id)
    field(:name, :string)
    field(:item_id, :id)

    permit(schema: Subitem)
  end

  object :item do
    field(:id, :id)
    field(:permission_level, :integer)
    field(:thread_name, :string)
    field(:owner_id, :id)

    field(:subitems, list_of(:subitem), resolve: &authorized_dataloader/3)

    permit(schema: Item)
  end

  # Queries
  query do
    field :item, :item do
      arg(:id, non_null(:id))

      permit(action: :read)

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    # Test field with non_null(list_of(...)) wrapper
    field :items_non_null, non_null(list_of(:item)), directives: [:load_and_authorize] do
      permit(action: :read)

      resolve(fn _, %{context: %{loaded_resources: items}} ->
        {:ok, items}
      end)
    end

    # Test field with list_of(non_null(...)) wrapper
    field :items_inner_non_null, list_of(non_null(:item)), directives: [:load_and_authorize] do
      permit(action: :read)

      resolve(fn _, %{context: %{loaded_resources: items}} ->
        {:ok, items}
      end)
    end

    field :item_by_thread_name, :item do
      arg(:thread_name, non_null(:string))

      permit(action: :read, id_param_name: :thread_name, id_struct_field_name: :thread_name)

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :subitem, :subitem do
      arg(:id, non_null(:id))

      permit(action: :read)

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :subitem_by_name, :subitem do
      arg(:name, non_null(:string))

      permit(action: :read, id_param_name: :name, id_struct_field_name: :name)

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :items, list_of(:item), directives: [:load_and_authorize] do
      permit(action: :read)

      resolve(fn _, %{context: %{loaded_resources: items}} ->
        {:ok, items}
      end)
    end

    field :user, :user do
      arg(:id, non_null(:id))

      permit(action: :read)

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :me, :user do
      middleware(Permit.Absinthe.Middleware.DataloaderSetup)

      permit(action: :read)

      resolve(fn _, _, %{context: %{current_user: current_user}} ->
        {:ok, current_user}
      end)
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

  def plugins do
    [Absinthe.Middleware.Dataloader | Absinthe.Plugin.defaults()]
  end
end
