defmodule Permit.AbsintheFakeApp.Schema do
  @moduledoc false
  use Absinthe.Schema
  use Permit.Absinthe, authorization_module: Permit.AbsintheFakeApp.Authorization

  @prototype_schema Permit.Absinthe.Schema.Prototype

  alias Permit.Absinthe, as: PermitAbsinthe
  alias Permit.AbsintheFakeApp.{Item, Subitem, User}

  import Ecto.Query

  def external_items_for_owner(owner_id) do
    [
      %Item{id: 901, owner_id: owner_id, permission_level: 1, thread_name: "external_1"},
      %Item{id: 902, owner_id: owner_id, permission_level: 1, thread_name: "external_2"}
    ]
  end

  def external_items_loader(%{params: %{owner_id: owner_id}}) do
    external_items_for_owner(owner_id)
  end

  def fetch_subject_custom_user(%{resolution: resolution}) do
    get_in(resolution.context, [:custom_user])
  end

  def item_with_custom_base_query(%{params: params}) do
    query = from(i in Item, where: i.id == ^params.id)

    case params do
      %{owner_id: owner_id} -> where(query, [i], i.owner_id == ^owner_id)
      _ -> query
    end
  end

  def items_with_finalize_query(query, %{params: params}) do
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

  def handle_unauthorized_custom(%{action: action, resource_module: module}) do
    {:error,
     %{
       message: "Custom unauthorized for #{action} on #{inspect(module)}",
       code: "CUSTOM_FORBIDDEN"
     }}
  end

  def handle_not_found_custom(%{params: params}) do
    {:error,
     %{
       message: "Custom not found",
       code: "CUSTOM_NOT_FOUND",
       params: params
     }}
  end

  def item_with_custom_loader(%{params: %{id: id}}) do
    %Item{
      id: id,
      permission_level: 1,
      thread_name: "custom_loaded",
      owner_id: 1
    }
  end

  def items_with_custom_loader(_context) do
    [
      %Item{id: 101, owner_id: 1, permission_level: 1, thread_name: "custom_list_admin"},
      %Item{id: 102, owner_id: 2, permission_level: 1, thread_name: "custom_list_owner"},
      %Item{id: 103, owner_id: 3, permission_level: 1, thread_name: "custom_list_inspector"}
    ]
  end

  def items_with_nil_loader(_context), do: nil

  def item_with_empty_list_loader(_context), do: []

  def items_with_wrapped_response_loader(_context) do
    [
      %Item{id: 201, owner_id: 1, permission_level: 1, thread_name: "wrap_1"},
      %Item{id: 202, owner_id: 1, permission_level: 1, thread_name: "wrap_2"}
    ]
  end

  def items_with_wrapped_response_wrap(items), do: {:ok, Enum.reverse(items)}

  def items_with_custom_subject_fetch_subject(%{resolution: resolution}) do
    resolution.context[:custom_user] || resolution.context[:current_user]
  end

  def items_with_custom_subject_base_query(_context),
    do: from(i in Item, where: i.permission_level >= 1)

  def handler_wins_unauthorized(_ctx), do: {:error, "Handler wins"}

  def base_query_item_by_id(%{params: %{id: id}}), do: from(i in Item, where: i.id == ^id)

  def wrap_authorized_identity(item), do: {:ok, item}

  def combined_options_unauthorized(_ctx), do: {:error, "Combined options: unauthorized"}

  def item_with_nil_loader(%{params: _params}), do: nil

  def item_with_raising_loader(%{params: _params}), do: raise("Loader error")

  def wrap_error(_item), do: {:error, "Custom error from wrap"}

  def raising_fetch_subject(%{resolution: _resolution}), do: raise("fetch_subject error")

  def raising_unauthorized_handler(_ctx), do: raise("unauthorized handler error")

  def raising_not_found_base_query(_ctx), do: from(i in Item, where: i.id == -999)

  def raising_not_found_handler(_ctx), do: raise("not found handler error")

  def raising_wrap_authorized(_item), do: raise("wrap_authorized error")

  def invalid_wrap_return(_item), do: "invalid return type"

  def invalid_wrap_return_tuple(_item), do: {:custom, "response"}

  def create_item_with_custom_options_unauthorized(_ctx),
    do: {:error, %{message: "Cannot create item", code: "CREATE_FORBIDDEN"}}

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

    field :items_with_local_helper_loader, list_of(:item) do
      arg(:owner_id, non_null(:id))

      permit(
        action: :read,
        loader: fn %{params: %{owner_id: owner_id}} ->
          external_items_for_owner(owner_id)
        end
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :items_with_local_capture_loader, list_of(:item) do
      arg(:owner_id, non_null(:id))

      permit(
        action: :read,
        loader: &external_items_loader/1
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :user, :user do
      arg(:id, non_null(:id))

      permit(action: :read)

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :me, :user do
      permit(action: :read)

      resolve(fn _, _, %{context: %{current_user: current_user}} ->
        {:ok, current_user}
      end)
    end

    field :item_with_custom_subject, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        fetch_subject: &fetch_subject_custom_user/1
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_custom_base_query, :item do
      arg(:id, non_null(:id))
      arg(:owner_id, :id)

      permit(
        action: :read,
        base_query: &item_with_custom_base_query/1
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :items_with_finalize_query, list_of(:item) do
      arg(:limit, :integer)
      arg(:offset, :integer)

      permit(
        action: :read,
        finalize_query: &items_with_finalize_query/2
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_custom_unauthorized, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        handle_unauthorized: &handle_unauthorized_custom/1
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_custom_not_found, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        handle_not_found: &handle_not_found_custom/1
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
        loader: &item_with_custom_loader/1
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :items_with_custom_loader, list_of(:item) do
      permit(
        action: :read,
        loader: &items_with_custom_loader/1
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :items_with_nil_loader, list_of(:item) do
      permit(
        action: :read,
        loader: &items_with_nil_loader/1
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_empty_list_loader, :item do
      arg(:id, :id)

      permit(
        action: :read,
        loader: &item_with_empty_list_loader/1
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :items_with_wrapped_response, list_of(:item) do
      permit(
        action: :read,
        loader: &items_with_wrapped_response_loader/1,
        wrap_authorized: &items_with_wrapped_response_wrap/1
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :items_with_custom_subject, list_of(:item) do
      permit(
        action: :read,
        fetch_subject: &items_with_custom_subject_fetch_subject/1,
        base_query: &items_with_custom_subject_base_query/1
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_handler_and_message, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        handle_unauthorized: &handler_wins_unauthorized/1,
        unauthorized_message: "Should not be used",
        base_query: &base_query_item_by_id/1
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_wrapped_response, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        wrap_authorized: &wrap_authorized_identity/1
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_combined_options, :item do
      arg(:id, non_null(:id))
      arg(:owner_id, :id)

      permit(
        action: :read,
        base_query: &item_with_custom_base_query/1,
        fetch_subject: &items_with_custom_subject_fetch_subject/1,
        handle_unauthorized: &combined_options_unauthorized/1
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_nil_loader, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        loader: &item_with_nil_loader/1
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_raising_loader, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        loader: &item_with_raising_loader/1
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_error_wrap, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        wrap_authorized: &wrap_error/1
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_raising_fetch_subject, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        fetch_subject: &raising_fetch_subject/1
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_raising_unauthorized_handler, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        handle_unauthorized: &raising_unauthorized_handler/1
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_raising_not_found_handler, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        base_query: &raising_not_found_base_query/1,
        handle_not_found: &raising_not_found_handler/1
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_raising_wrap_authorized, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        wrap_authorized: &raising_wrap_authorized/1
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_invalid_wrap_return, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        wrap_authorized: &invalid_wrap_return/1
      )

      resolve(&PermitAbsinthe.load_and_authorize/2)
    end

    field :item_with_invalid_wrap_return_tuple, :item do
      arg(:id, non_null(:id))

      permit(
        action: :read,
        wrap_authorized: &invalid_wrap_return_tuple/1
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

      middleware(Permit.Absinthe.Middleware)

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
        handle_unauthorized: &create_item_with_custom_options_unauthorized/1
      )

      middleware(Permit.Absinthe.Middleware)

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
