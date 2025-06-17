defmodule Permit.Absinthe.Schema.Meta do
  @doc """
  Extracts meta information from a field's return type in a resolver.

  ## Examples

      def resolve_article(_, _, resolution) do
        meta = get_type_meta_from_resolution(resolution)
        # meta will contain %{schema: Blog.Content.Article}
        # ...
      end
  """
  def get_type_meta_from_resolution(resolution, meta_keys) when is_list(meta_keys) do
    type =
      case resolution.definition.schema_node.type do
        %{of_type: inner_type} -> inner_type
        other -> other
      end
      |> resolution.schema.__absinthe_type__()

    meta = type.__private__[:meta] || []

    get_in(meta, meta_keys)
  end

  def get_type_meta_from_resolution(resolution, meta_key) when is_atom(meta_key) do
    get_type_meta_from_resolution(resolution, [meta_key])
  end

  def get_field_meta_from_resolution(resolution, meta_keys) when is_list(meta_keys) do
    meta = resolution.definition.schema_node.__private__[:meta] || []

    get_in(meta, meta_keys)
  end

  def get_field_meta_from_resolution(resolution, meta_key) when is_atom(meta_key) do
    get_field_meta_from_resolution(resolution, [meta_key])
  end

  def get_type_name(resolution) do
    case resolution.definition.schema_node.type do
      %{of_type: inner_type} -> inner_type
      other -> other
    end
  end
end
