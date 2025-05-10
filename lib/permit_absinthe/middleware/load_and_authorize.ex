defmodule Permit.Absinthe.Middleware.LoadAndAuthorize do
  @moduledoc """
  Middleware for loading and authorizing resources in Absinthe.

  This middleware is used to load and authorize resources in Absinthe.
  It can be used as a middleware in Absinthe schema definitions.

  ## Example

    ```elixir
    mutation do
      @desc "Update an article"
      field :update_article, :article do
        permit action: :update

        arg(:id, non_null(:id))
        arg(:name, non_null(:string))
        arg(:content, non_null(:string))

        middleware Permit.Absinthe.Middleware.LoadAndAuthorize, :one

        resolve(fn _, %{name: name, content: content}, %{context: context} ->
          case Blog.Content.update_article(context.loaded_resource, %{name: name, content: content}) do
            {:ok, article} ->
              {:ok, article}

            {:error, changeset} ->
              {:error, "Could not update article"}
          end
        end)
      end
    end
    ```
  """

  @behaviour Absinthe.Middleware

  alias Permit.Absinthe.Schema.{Helpers, Meta}

  @impl true
  def call(resolution, arity) when arity in [:one, :all] do
    case Permit.Absinthe.LoadAndAuthorize.load_and_authorize(
           resolution.arguments,
           resolution,
           arity
         ) do
      {:ok, resource} ->
        key =
          case arity do
            :one -> :loaded_resource
            :all -> :loaded_resources
          end

        new_context = Map.put(resolution.context, key, resource)
        %{resolution | context: new_context}

      {:error, error} ->
        Absinthe.Resolution.put_result(resolution, {:error, error})
    end
  end
end
