defmodule PermitAbsintheDemo.Context do
  @moduledoc """
  Convenience context for loading demo data through the Repo.
  """
  alias PermitAbsintheDemo.{Post, Repo, User}

  def get_post(id), do: Repo.get(Post, id)
  def list_posts, do: Repo.all(Post)

  def get_user(id), do: Repo.get(User, id)
  def list_users, do: Repo.all(User)
end
