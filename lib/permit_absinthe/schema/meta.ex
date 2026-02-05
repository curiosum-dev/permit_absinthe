defmodule Permit.Absinthe.Schema.Meta do
  @moduledoc """
  This module provides a way to extract meta information from a field's return type in a resolver.

  *Part of the private API and not meant for public use.*
  """

  # Helper function to recursively unwrap type wrappers (List, NonNull) to get the base type identifier
  defp unwrap_type(%{of_type: inner_type}), do: unwrap_type(inner_type)
  defp unwrap_type(type), do: type

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
    case resolution do
      %{definition: %{schema_node: schema_node}, schema: schema} ->
        # Recursively unwrap List and NonNull wrappers to get the base type identifier
        type_ref = unwrap_type(schema_node.type)
        type = schema.__absinthe_type__(type_ref)

        case type do
          %{__private__: private} when not is_nil(private) ->
            get_in(private[:meta] || [], meta_keys)

          _ ->
            nil
        end

      _ ->
        nil
    end
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
    case resolution do
      %{definition: %{schema_node: schema_node}} -> unwrap_type(schema_node.type)
      _ -> nil
    end
  end
end
