defmodule Permit.AbsintheFakeApp.Schema do
  @moduledoc false
  use Absinthe.Schema
  use Permit.Absinthe, authorization_module: Permit.AbsintheFakeApp.Authorization

  @prototype_schema Permit.Absinthe.Schema.Prototype

  alias Permit.Absinthe, as: PermitAbsinthe
  alias Permit.AbsintheFakeApp.{Item, Subitem, User}

  import Ecto.Query

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

    field :item_with_custom_subject, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        fetch_subject: fn %{resolution: resolution} ->
          get_in(resolution.context, [:custom_user])
        end
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_custom_base_query, :item do
      arg(:id, non_null(:id))
      arg(:owner_id, :id)

      permit(
        action: :read,
        base_query: fn %{params: params} ->
          query = from(i in Item, where: i.id == ^params.id)

          case params do
            %{owner_id: owner_id} ->
              where(query, [i], i.owner_id == ^owner_id)

            _ ->
              query
          end
        end
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :items_with_finalize_query, list_of(:item) do
      arg(:limit, :integer)
      arg(:offset, :integer)

      permit(
        action: :read,
        finalize_query: fn query, %{params: params} ->
          query =
            case params do
              %{limit: limit} -> limit(query, ^limit)
              _ -> query
            end

          case params do
            %{offset: offset} -> offset(query, ^offset)
            _ -> query
          end
        end
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_custom_unauthorized, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        handle_unauthorized: fn %{action: action, resource_module: module} ->
          {:error,
           %{
             message: "Custom unauthorized for #{action} on #{inspect(module)}",
             code: "CUSTOM_FORBIDDEN"
           }}
        end
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_custom_not_found, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        handle_not_found: fn %{params: params} ->
          {:error,
           %{
             message: "Custom not found",
             code: "CUSTOM_NOT_FOUND",
             params: params
           }}
        end
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_custom_message, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        unauthorized_message: "You don't have permission to view this item"
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_custom_loader, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        loader: fn %{params: %{id: id}} ->
          %Item{
            id: id,
            permission_level: 1,
            thread_name: "custom_loaded",
            owner_id: 1
          }
        end
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_wrapped_response, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        wrap_authorized: fn item ->
          {:ok, item}
        end
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_combined_options, :item do
      arg(:id, non_null(:id))
      arg(:owner_id, :id)

      permit(
        action: :read,
        base_query: fn %{params: params} ->
          query = from(i in Item, where: i.id == ^params.id)

          case params do
            %{owner_id: owner_id} -> where(query, [i], i.owner_id == ^owner_id)
            _ -> query
          end
        end,
        fetch_subject: fn %{resolution: resolution} ->
          resolution.context[:custom_user] || resolution.context[:current_user]
        end,
        handle_unauthorized: fn _ ->
          {:error, "Combined options: unauthorized"}
        end
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_nil_loader, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        loader: fn %{params: _params} ->
          nil
        end
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_raising_loader, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        loader: fn %{params: _params} ->
          raise "Loader error"
        end
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_error_wrap, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        wrap_authorized: fn _item ->
          {:error, "Custom error from wrap"}
        end
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_raising_fetch_subject, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        fetch_subject: fn %{resolution: _resolution} ->
          raise "fetch_subject error"
        end
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_raising_unauthorized_handler, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        handle_unauthorized: fn _ ->
          raise "unauthorized handler error"
        end
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_raising_not_found_handler, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        base_query: fn _ ->
          from(i in Item, where: i.id == -999)
        end,
        handle_not_found: fn _ ->
          raise "not found handler error"
        end
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_raising_wrap_authorized, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        wrap_authorized: fn _item ->
          raise "wrap_authorized error"
        end
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_invalid_wrap_return, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        wrap_authorized: fn _item ->
          "invalid return type"
        end
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_invalid_wrap_return_tuple, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        wrap_authorized: fn _item ->
          {:custom, "response"}
        end
      )

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

    field :create_item_with_custom_options, :item do
      arg(:permission_level, :integer)
      arg(:thread_name, :string)

      permit(
        action: :create,
        handle_unauthorized: fn _ ->
          {:error, %{message: "Cannot create item", code: "CREATE_FORBIDDEN"}}
        end
      )

      middleware(Permit.Absinthe.Middleware.LoadAndAuthorize)

      resolve(fn args, %{context: %{current_user: current_user}} ->
        if current_user do
          {:ok,
           %Item{
             permission_level: args.permission_level,
             thread_name: args.thread_name,
             owner_id: current_user.id
           }}
        else
          {:error, "No user"}
        end
      end)
    end
  end

  def plugins do
    [Absinthe.Middleware.Dataloader | Absinthe.Plugin.defaults()]
  end
end
