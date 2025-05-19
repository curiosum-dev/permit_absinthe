defmodule Permit.AbsintheFakeApp.Permissions do
  use Permit.Ecto.Permissions, actions_module: Permit.AbsintheFakeApp.Actions

  alias Permit.AbsintheFakeApp.Item
  alias Permit.AbsintheFakeApp.User

  def can(%User{roles: roles} = user) do
    ["admin", "owner", "inspector"]
    |> Enum.find(fn role -> role in roles end)
    |> then(fn role -> can(user, role) end)
  end

  def can(_user), do: permit()

  def can(_user, "admin") do
    permit()
    |> all(Item)
  end

  def can(_user, "owner") do
    permit()
    |> all(Item, [user, item], owner_id: user.id)
  end

  def can(_user, "inspector") do
    permit()
    |> read(Item)
  end

  def can(%User{id: id} = _user, _) do
    permit()
    |> all(Item, owner_id: id)
  end
end
