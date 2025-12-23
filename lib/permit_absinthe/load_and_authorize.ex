defmodule Permit.Absinthe.LoadAndAuthorize do
  @moduledoc """
  This module contains the load_and_authorize/2 function that can be used from within
  a custom resolver function, or as a resolver function in its entirety.
  """

  alias Permit.Absinthe.Schema.{Helpers, Meta}

  @doc """
  Resolves and authorizes a resource or list of resources.

  This function can be used as a resolver function directly or called from a custom resolver.

  ## Parameters

  * `args` - The arguments passed to the field
  * `resolution` - The Absinthe resolution struct

  ## Examples

      # As a resolver function
      field :post, :post do
        arg :id, non_null(:id)
        resolve &load_and_authorize/2
      end

      # Resolver for a list of resources
      field :posts, list_of(:post) do
        resolve &load_and_authorize/2
      end

      # From a custom resolver
      def my_custom_resolver(parent, args, resolution) do
        case load_and_authorize(parent, args, resolution, :one) do
          {:ok, resource} ->
            # Do something with the authorized resource
            {:ok, transform_resource(resource)}

          error ->
            error
        end
      end
  """
  def load_and_authorize(args, resolution) do
    type_meta = Meta.get_type_meta_from_resolution(resolution, :permit)
    field_meta = Meta.get_field_meta_from_resolution(resolution, :permit)

    module = type_meta[:schema]
    action = field_meta[:action] || Helpers.default_action(resolution)

    authorization_module =
      Meta.get_field_meta_from_resolution(resolution, :authorization_module)

    resolution_context =
      build_resolution_context(args, resolution, field_meta, type_meta, authorization_module)

    subject = fetch_subject(resolution_context, field_meta)

    if is_nil(subject) do
      handle_unauthorized(resolution_context, field_meta)
    else
      arity = determine_arity(resolution)

      case authorize_and_load(
             subject,
             authorization_module,
             module,
             action,
             resolution_context,
             arity
           ) do
        {:authorized, resource} ->
          wrap_authorized_response(resource, field_meta, resolution_context.resolution)

        :unauthorized ->
          handle_unauthorized(resolution_context, field_meta)

        :not_found ->
          handle_not_found(resolution_context, field_meta)
      end
    end
  end

  defp build_resolution_context(args, resolution, field_meta, type_meta, authorization_module) do
    %{
      params: args,
      resolution: resolution,
      field_meta: field_meta,
      type_meta: type_meta,
      action: field_meta[:action] || Helpers.default_action(resolution),
      resource_module: type_meta[:schema],
      authorization_module: authorization_module,
      base_query:
        field_meta |> get_field(:base_query) |> get_fn_from_ast(1, resolution) ||
          (&Helpers.base_query/1),
      finalize_query: field_meta |> get_field(:finalize_query) |> get_fn_from_ast(2, resolution)
    }
  end

  defp get_field(meta, key) do
    cond do
      is_map(meta) -> meta[key]
      is_list(meta) -> Keyword.get(meta, key)
      true -> nil
    end
  end

  defp get_fn_from_ast(value, arity, resolution)

  defp get_fn_from_ast(f, arity, _resolution) when is_function(f, arity), do: f

  defp get_fn_from_ast({:fn, _meta, _clauses} = fn_ast, arity, resolution) do
    schema = resolution && resolution.schema

    fn_ast =
      if is_atom(schema) do
        qualify_local_schema_calls(fn_ast, schema)
      else
        fn_ast
      end

    with {function, _} <- Code.eval_quoted(fn_ast, []),
         true <- is_function(function, arity) do
      function
    else
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp get_fn_from_ast({:&, _meta, _clauses} = capture_ast, arity, _resolution) do
    with {function, _} <- Code.eval_quoted(capture_ast, []),
         true <- is_function(function, arity) do
      function
    else
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp get_fn_from_ast(_, _, _), do: nil

  # Changes from:
  #
  # fn %{params: %{owner_id: owner_id}} ->
  #   get_external_notes(owner_id)
  # end
  #
  # to:
  #
  # fn %{params: %{owner_id: owner_id}} ->
  #   ModuleName.get_external_notes(owner_id)
  # end
  defp qualify_local_schema_calls(ast, schema) do
    Macro.prewalk(ast, fn
      {name, meta, args} = node when is_atom(name) and is_list(args) ->
        arity = length(args)

        if function_exported?(schema, name, arity) do
          {{:., meta, [schema, name]}, meta, args}
        else
          node
        end

      other ->
        other
    end)
  end

  defp fetch_subject(context, field_meta) do
    case field_meta |> get_field(:fetch_subject) |> get_fn_from_ast(1, context.resolution) do
      nil ->
        context.resolution.context[:current_user]

      fetch_subject_fn ->
        try do
          fetch_subject_fn.(context)
        rescue
          _ -> nil
        end
    end
  end

  defp handle_unauthorized(context, field_meta) do
    case field_meta
         |> get_field(:handle_unauthorized)
         |> get_fn_from_ast(1, context.resolution) do
      nil ->
        message = field_meta[:unauthorized_message] || "Unauthorized"
        {:error, message}

      handle_unauthorized_fn ->
        try do
          handle_unauthorized_fn.(context)
        rescue
          _ -> {:error, "Unauthorized"}
        end
    end
  end

  defp handle_not_found(context, field_meta) do
    case field_meta |> get_field(:handle_not_found) |> get_fn_from_ast(1, context.resolution) do
      nil ->
        {:error, "Not found"}

      handle_not_found_fn ->
        try do
          handle_not_found_fn.(context)
        rescue
          _ -> {:error, "Not found"}
        end
    end
  end

  defp wrap_authorized_response(resource, field_meta, resolution) do
    case field_meta |> get_field(:wrap_authorized) |> get_fn_from_ast(1, resolution) do
      nil ->
        {:ok, resource}

      wrap_authorized_fn ->
        try do
          case wrap_authorized_fn.(resource) do
            {:ok, wrapped_resource} ->
              {:ok, wrapped_resource}

            {:error, error} ->
              {:error, error}

            _ ->
              {:error, "wrap_authorized function returned invalid type"}
          end
        rescue
          _ -> {:error, "wrap_authorized function raised an exception"}
        end
    end
  end

  defp authorize_and_load(subject, authorization_module, module, action, context, arity) do
    case context.field_meta |> get_field(:loader) |> get_fn_from_ast(1, context.resolution) do
      nil ->
        meta = %{
          params: context.params,
          resolution: context.resolution,
          base_query: context.base_query,
          finalize_query: context.finalize_query || fn query, _ctx -> query end
        }

        authorization_module.resolver_module().resolve(
          subject,
          authorization_module,
          module,
          action,
          meta,
          arity
        )

      loader_fn ->
        loaded =
          try do
            loader_fn.(context)
          rescue
            _ -> nil
          end

        case {arity, loaded} do
          {_, nil} ->
            :not_found

          {:all, items} ->
            items
            |> normalize_list()
            |> Enum.filter(
              &authorization_module.resolver_module().authorized?(
                subject,
                authorization_module,
                &1,
                action
              )
            )
            |> then(&{:authorized, &1})

          {:one, []} ->
            :not_found

          {:one, list} when is_list(list) ->
            authorize_single(subject, authorization_module, action, List.first(list))

          {:one, item} ->
            authorize_single(subject, authorization_module, action, item)
        end
    end
  end

  defp normalize_list(list) when is_list(list), do: list
  defp normalize_list(nil), do: []
  defp normalize_list(item), do: [item]

  defp authorize_single(subject, authorization_module, action, item) do
    if authorization_module.resolver_module().authorized?(
         subject,
         authorization_module,
         item,
         action
       ) do
      {:authorized, item}
    else
      :unauthorized
    end
  end

  defp determine_arity(%{definition: %{schema_node: schema_node}} = _resolution) do
    if has_list_type?(schema_node.type), do: :all, else: :one
  end

  defp determine_arity(_), do: :one

  # Check if a type contains a List at any level of wrapping (NonNull, etc.)
  defp has_list_type?(%Absinthe.Type.List{}), do: true
  defp has_list_type?(%{of_type: inner_type}), do: has_list_type?(inner_type)
  defp has_list_type?(_), do: false
end
