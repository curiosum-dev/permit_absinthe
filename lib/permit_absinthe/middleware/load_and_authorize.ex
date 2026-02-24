defmodule Permit.Absinthe.Middleware.LoadAndAuthorize do
  @moduledoc """
  Deprecated. Use `Permit.Absinthe.Middleware` instead.
  """

  @deprecated "Use Permit.Absinthe.Middleware instead"

  @behaviour Absinthe.Middleware

  @impl true
  def call(resolution, opts) do
    IO.warn(
      "Permit.Absinthe.Middleware.LoadAndAuthorize is deprecated, use Permit.Absinthe.Middleware instead",
      []
    )

    Permit.Absinthe.Middleware.call(resolution, opts)
  end
end
