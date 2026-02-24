defmodule Permit.Absinthe.Resolvers.LoadAndAuthorize do
  @moduledoc """
  Absinthe resolver that loads and authorizes a resource or list of resources
  by combining Permit's authorization rules with Ecto-based query scoping.

  ## Usage and mechanism

  In the basic scenario, Ecto is used to filter out records matching defined
  authorization permissions. The _happy path_ works in the following way:

  1. Use the `Permit.Absinthe` mixin to point to the application's authorization
  module that configures permissions & action names, as well as points `Permit.Ecto`
  to the application's Ecto `Repo`.

  ```
  use Permit.Absinthe, authorization_module: MyApp.Authorization
  ```

  2. When a GraphQL field resolves through `load_and_authorize/2`, the subject
  (`resolution.context[:current_user]` by default) is matched with the action
  configured via the `permit` macro option.

  ```
  field :notes, list_of(non_null(:note)) do
    permit action: :read
    resolve &PermitAbsinthe.load_and_authorize/2
  end
  ```

  The resource module, which is typically an Ecto schema, is configured in the
  GraphQL type via the `:schema` option in the `permit` macro.

  ```
  object :note do
    # fields

    permit(schema: Note)
  end
  ```

  3. `Permit.Ecto.Resolver` uses the subject and authorization module to ask
  for permission to take the `:action` by the current user on objects of the
  resource module's struct type. If permission is granted, configured permissions
  are converted to Ecto query.

  ```
  # This permission...
  def can(user) do
    permit() |> read(Note, user_id: user.id)
  end

  # ...gets converted to the following query:
  SELECT * FROM notes WHERE user_id: $1;
  ```

  For single-object queries (e.g. `note(id: 123)`), the ID param is applied to the
  query as well.

  4. If the field is configured as a `list_of(...)` node, the list of retrieved
  records is returned by the resolver as an `{:ok, [%Note{}, ...]}` tuple. If it's
  a single-object node, the resolver function returns `{:ok, %Note{}}`.

  ## Error handling

  An error tuple is returned when:
  - `{:error, "Not found"}` - in single-object queries when the SQL query with
  authorization conditions returns 0 records and an additional query (with only
  the ID condition) indicates that a record indeed does not exist at all
  - `{:error, "Unauthorized"}` - when authorization fails at any point, or the
  additional query indicated that a record with the given ID does exist (so
  the query-based authorization has failed).

  ## Additional options

  See `Permit.Absinthe.permit/1` macro for additional options allowing customization
  of queries, error handling, current user (subject) retrieval, and ID parameter
  & ID field naming.

  ## Usage as middleware

  For mutations, pair `Permit.Absinthe.Middleware.LoadAndAuthorize` with a
  custom resolver. The middleware loads and authorizes the resource using
  the `load_and_authorize/2` resolver function, then places it in the context
  as `:loaded_resource` (single) or `:loaded_resources` (list):

  ### Example

  ```
  mutation do
    field :update_post, :post do
      permit action: :update
      arg :id, non_null(:id)
      arg :title, :string

      middleware Permit.Absinthe.Middleware.LoadAndAuthorize

      resolve fn _, args, %{context: %{loaded_resource: post}} ->
        MyApp.Blog.update_post(post, args)
      end
    end
  end
  ```
  See more in `Permit.Absinthe.Middleware` documentation.

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

    # For create actions there is no existing record to load, so we check
    # authorization against a blank struct. This ensures field-level conditions
    # (e.g. owner_id: user.id) are evaluated against nil rather than bypassed
    # by the module-atom shortcut in ParsedCondition.satisfied?/3, which
    # would otherwise allow any conditioned rule to pass unconditionally.
    cond do
      is_nil(subject) ->
        handle_unauthorized(resolution_context, field_meta)

      create_action?(action, authorization_module) ->
        blank = module.__struct__()

        if authorization_module.resolver_module().authorized?(subject, authorization_module, blank, action) do
          wrap_authorized_response(nil, field_meta, resolution_context.resolution)
        else
          handle_unauthorized(resolution_context, field_meta)
        end

      true ->
        arity = determine_arity(resolution)

        case authorize_and_load(subject, authorization_module, module, action, resolution_context, arity) do
          {:authorized, resource} -> wrap_authorized_response(resource, field_meta, resolution_context.resolution)
          :unauthorized -> handle_unauthorized(resolution_context, field_meta)
          :not_found -> handle_not_found(resolution_context, field_meta)
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

  defp get_fn_from_ast({:&, _meta, _clauses} = capture_ast, arity, resolution) do
    schema = resolution && resolution.schema

    capture_ast =
      if is_atom(schema) do
        qualify_local_capture(capture_ast, schema)
      else
        capture_ast
      end

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

  defp qualify_local_schema_calls(ast, schema) do
    # When users pass inline anonymous functions to `permit` (e.g. `base_query: fn ctx -> ... end`)
    # those functions may call helpers defined in the schema module (e.g. `notes_base_query(ctx)`).
    #
    # Because we capture/eval the callback AST, we rewrite *local* calls into remote calls
    # (`SchemaModule.notes_base_query(...)`) so they can be resolved at runtime.
    #
    # Note: the target functions must be public (`def`) for `function_exported?/3` to match.
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

  defp qualify_local_capture(
         {:&, cap_meta, [{:/, slash_meta, [{name, name_meta, ctx}, arity]}]},
         schema
       )
       when is_atom(name) and is_integer(arity) do
    # Users commonly pass captures like `&my_loader/1` or `&my_handler/1`.
    # If that capture refers to a function defined in the schema module, it starts as a *local*
    # capture (no module qualifier). Here we qualify it to `&SchemaModule.my_loader/1`.
    #
    # Note: private functions (`defp`) cannot be captured remotely; they must be public (`def`).
    if function_exported?(schema, name, arity) and (ctx == nil or ctx == Elixir) do
      remote_fun = {{:., name_meta, [schema, name]}, name_meta, []}
      {:&, cap_meta, [{:/, slash_meta, [remote_fun, arity]}]}
    else
      {:&, cap_meta, [{:/, slash_meta, [{name, name_meta, ctx}, arity]}]}
    end
  end

  defp qualify_local_capture(other, _schema), do: other

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
    loader = context.field_meta |> get_field(:loader) |> get_fn_from_ast(1, context.resolution)

    if loader do
      authorize_loaded_resource(
        loader,
        subject,
        authorization_module,
        action,
        context,
        arity
      )
    else
      resolve_default(subject, authorization_module, module, action, context, arity)
    end
  end

  defp resolve_default(subject, authorization_module, module, action, context, arity) do
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
  end

  defp authorize_loaded_resource(loader_fn, subject, authorization_module, action, context, arity) do
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

  # Create actions have no pre-existing record to load — authorization is a
  # pure capability check on the resource module, not a record instance.
  # We detect this by checking if the action is :create or is defined in the
  # grouping schema as requiring :create (e.g. a custom :new action that maps to :create).
  defp create_action?(action, authorization_module) do
    actions_module = authorization_module.actions_module()
    grouping = actions_module.grouping_schema()
    action == :create or :create in (Map.get(grouping, action) || [])
  rescue
    _ -> action == :create
  end
end
