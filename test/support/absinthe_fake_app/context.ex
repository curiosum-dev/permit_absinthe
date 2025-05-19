defmodule Permit.AbsintheFakeApp.Context do
  @moduledoc """
  Context module for Absinthe fake app.
  This module provides functions to query items and users.
  """

  alias Permit.AbsintheFakeApp.{Item, Repo, User}

  def get_item(id), do: Repo.get(Item, id)
  def list_items, do: Repo.all(Item)

  def get_user(id), do: Repo.get(User, id)
  def list_users, do: Repo.all(User)

  def get_item_by(attrs), do: Repo.get_by(Item, attrs)
end
