defmodule PermitAbsintheDemoWeb.ContextPlug do
  @moduledoc """
  Builds the Absinthe context from incoming request headers.

  - `x-user-id`: loads a user as `:current_user`
  - `x-custom-user-id`: loads a user as `:custom_user` (used by the `:fetch_subject` demo)

  Injects the context into Absinthe via `Absinthe.Plug.put_options/2`.
  """
  import Plug.Conn
  alias PermitAbsintheDemo.{Repo, User}

  def init(opts), do: opts

  def call(conn, _opts) do
    context = build(conn)
    Absinthe.Plug.put_options(conn, context: context)
  end

  def build(conn) do
    %{
      current_user: load_user(conn, "x-user-id"),
      custom_user: load_user(conn, "x-custom-user-id")
    }
  end

  defp load_user(conn, header) do
    with [id] <- get_req_header(conn, header),
         {int, ""} <- Integer.parse(id) do
      Repo.get(User, int)
    else
      _ -> nil
    end
  end
end
