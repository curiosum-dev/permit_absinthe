defmodule PermitAbsintheDemoWeb.Schema do
  @moduledoc false

  use Absinthe.Schema
  use Permit.Absinthe, authorization_module: PermitAbsintheDemo.Authorization

  @prototype_schema Permit.Absinthe.Schema.Prototype

  import Ecto.Query

  alias PermitAbsintheDemo.{Note, Repo}

  import_types Absinthe.Type.Custom

  enum :user_role do
    value :admin
    value :user
  end

  object :user do
    permit schema: PermitAbsintheDemo.User

    field :id, non_null(:id)
    field :role, non_null(:user_role)
  end

  object :note do
    permit schema: Note

    field :id, non_null(:id)
    field :body, :string
    field :owner_id, :id
    field :deleted_at, :datetime
  end

  def external_notes_loader(%{params: _params}) do
    [
      %Note{id: 1, owner_id: 1, body: "Alice's first note"},
      %Note{id: 2, owner_id: 1, body: "Alice's second note"},
      %Note{id: 3, owner_id: 2, body: "Bob's note"},
    ]
  end

  def notes_base_query(_ctx) do
    from(n in Note, where: is_nil(n.deleted_at))
  end

  def notes_finalize_query(query, %{params: params}) do
    sort_by =
      params
      |> Map.get(:sort_by)
      |> parse_sort_by()

    sort_direction =
      case params do
        %{sort_direction: "desc"} -> :desc
        _ -> :asc
      end

    order_by(query, [n], [{^sort_direction, field(n, ^sort_by)}])
  end

  def fetch_custom_user(%{resolution: %{context: context}}), do: context[:custom_user]

  def note_with_custom_base_query(%{params: %{id: id, owner_id: owner_id}}) do
    Note
    |> where([n], n.id == ^parse_id(id))
    |> where([n], n.owner_id == ^parse_id(owner_id))
  end

  def notes_with_finalize_query(query, %{params: params}) do
    query
    |> order_by([n], asc: n.id)
    |> maybe_offset(params[:offset])
    |> maybe_limit(params[:limit])
  end

  def custom_unauthorized(%{action: action, resource_module: resource_module}),
    do: {:error, "Custom unauthorized for #{action} on #{inspect(resource_module)}"}

  def custom_not_found(_ctx), do: {:error, "Custom not found"}

  def note_with_custom_loader(%{params: %{id: id}}),
    do: %Note{id: parse_id(id), owner_id: 1, body: "custom_loaded"}

  def note_with_nil_loader(_ctx), do: nil

  def note_with_raising_loader(_ctx), do: raise("boom")

  def wrapped_authorized(%Note{body: body} = note) when is_binary(body),
    do: {:ok, %Note{note | body: "wrapped: " <> body}}

  def wrapped_authorized(other), do: {:ok, other}

  def error_wrap(_note), do: {:error, "Custom error from wrap"}

  def raising_wrap(_note), do: raise("boom")

  def invalid_wrap_return(_note), do: :not_a_valid_return

  def invalid_wrap_return_tuple(_note), do: {:ok, :not_a_note}

  def combined_base_query(%{params: %{id: id}}), do: from(n in Note, where: n.id == ^parse_id(id))

  def fetch_current_user(%{resolution: %{context: context}}), do: context[:current_user]

  def create_note_loader(%{params: %{body: body}, resolution: %{context: context}}) do
    owner_id =
      case context[:current_user] do
        %{id: id} -> id
        _ -> nil
      end

    %Note{owner_id: owner_id, body: body}
  end

  query do
    field :external_notes, list_of(:note) do
      permit loader: &external_notes_loader/1

      resolve &Permit.Absinthe.load_and_authorize/2
    end

    field :note, :note do
      arg :id, non_null(:id)
      resolve &Permit.Absinthe.load_and_authorize/2
    end

    field :notes, list_of(:note) do
      arg :sort_by, :string
      arg :sort_direction, :string

      permit(
        action: :read,
        base_query: &notes_base_query/1,
        finalize_query: &notes_finalize_query/2
      )

      resolve &Permit.Absinthe.load_and_authorize/2
    end

    field :note_with_custom_subject, :note do
      permit fetch_subject: &fetch_custom_user/1

      arg :id, non_null(:id)
      resolve &Permit.Absinthe.load_and_authorize/2
    end

    field :note_with_custom_base_query, :note do
      permit base_query: &note_with_custom_base_query/1

      arg :id, non_null(:id)
      arg :owner_id, non_null(:id)
      resolve &Permit.Absinthe.load_and_authorize/2
    end

    field :notes_with_finalize_query, list_of(:note) do
      permit finalize_query: &notes_with_finalize_query/2

      arg :limit, :integer
      arg :offset, :integer
      resolve &Permit.Absinthe.load_and_authorize/2
    end

    field :note_with_custom_unauthorized, :note do
      permit handle_unauthorized: &custom_unauthorized/1

      arg :id, non_null(:id)
      resolve &Permit.Absinthe.load_and_authorize/2
    end

    field :note_with_custom_not_found, :note do
      permit handle_not_found: &custom_not_found/1

      arg :id, non_null(:id)
      resolve &Permit.Absinthe.load_and_authorize/2
    end

    field :note_with_unauthorized_message, :note do
      permit unauthorized_message: "You don't have permission to view this item"

      arg :id, non_null(:id)
      resolve &Permit.Absinthe.load_and_authorize/2
    end

    field :note_with_custom_loader, :note do
      permit loader: &note_with_custom_loader/1

      arg :id, non_null(:id)
      resolve &Permit.Absinthe.load_and_authorize/2
    end

    field :note_with_nil_loader, :note do
      permit loader: &note_with_nil_loader/1

      arg :id, non_null(:id)
      resolve &Permit.Absinthe.load_and_authorize/2
    end

    field :note_with_raising_loader, :note do
      permit loader: &note_with_raising_loader/1

      arg :id, non_null(:id)
      resolve &Permit.Absinthe.load_and_authorize/2
    end

    field :note_with_wrapped_authorized, :note do
      permit wrap_authorized: &wrapped_authorized/1

      arg :id, non_null(:id)
      resolve &Permit.Absinthe.load_and_authorize/2
    end

    field :note_with_error_wrap, :note do
      permit wrap_authorized: &error_wrap/1

      arg :id, non_null(:id)
      resolve &Permit.Absinthe.load_and_authorize/2
    end

    field :note_with_raising_wrap_authorized, :note do
      permit wrap_authorized: &raising_wrap/1

      arg :id, non_null(:id)
      resolve &Permit.Absinthe.load_and_authorize/2
    end

    field :note_with_invalid_wrap_return, :note do
      permit wrap_authorized: &invalid_wrap_return/1

      arg :id, non_null(:id)
      resolve &Permit.Absinthe.load_and_authorize/2
    end

    field :note_with_invalid_wrap_return_tuple, :note do
      permit wrap_authorized: &invalid_wrap_return_tuple/1

      arg :id, non_null(:id)
      resolve &Permit.Absinthe.load_and_authorize/2
    end

    field :note_with_combined_options, :note do
      permit base_query: &combined_base_query/1,
             fetch_subject: &fetch_current_user/1,
             unauthorized_message: "Combined options unauthorized"

      arg :id, non_null(:id)
      resolve &Permit.Absinthe.load_and_authorize/2
    end
  end

  mutation do
    field :update_note, :note do
      permit action: :update

      arg :id, non_null(:id)
      arg :body, non_null(:string)

      middleware Permit.Absinthe.Middleware.LoadAndAuthorize

      resolve fn _parent, %{body: body}, %{context: %{loaded_resource: %Note{} = note}} ->
        note
        |> Note.changeset(%{body: body})
        |> Repo.update()
      end
    end

    field :create_note_with_custom_options, :note do
      permit action: :create,
             handle_unauthorized: &custom_unauthorized/1,
             loader: &create_note_loader/1

      arg :body, non_null(:string)

      middleware Permit.Absinthe.Middleware.LoadAndAuthorize

      resolve fn _parent, %{body: body}, %{context: %{loaded_resource: %Note{} = note}} ->
        %Note{}
        |> Note.changeset(%{owner_id: note.owner_id, body: body})
        |> Repo.insert()
      end
    end
  end

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, limit) when is_integer(limit) and limit >= 0, do: limit(query, ^limit)
  defp maybe_limit(query, _), do: query

  defp maybe_offset(query, nil), do: query
  defp maybe_offset(query, offset) when is_integer(offset) and offset >= 0, do: offset(query, ^offset)
  defp maybe_offset(query, _), do: query

  defp parse_id(nil), do: nil
  defp parse_id(int) when is_integer(int), do: int

  defp parse_id(bin) when is_binary(bin) do
    case Integer.parse(bin) do
      {int, ""} -> int
      _ -> nil
    end
  end

  # Ensure safe dynamic order-by (avoid atom leaks from user-provided strings)
  defp parse_sort_by(field) when is_binary(field) do
    case String.downcase(field) do
      "id" -> :id
      "inserted_at" -> :inserted_at
      "updated_at" -> :updated_at
      _ -> :inserted_at
    end
  end

  defp parse_sort_by(_field), do: :inserted_at
end
