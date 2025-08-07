defmodule Permit.AbsintheFakeApp.Permissions do
  use Permit.Ecto.Permissions, actions_module: Permit.AbsintheFakeApp.Actions

  alias Permit.AbsintheFakeApp.Item
  alias Permit.AbsintheFakeApp.Subitem
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
    |> all(Subitem)
  end

  def can(user, "owner") do
    permit()
    |> all(Item, owner_id: user.id)
    # For now, let's allow access to all subitems for owner to isolate the issue
    |> all(Subitem)
  end

  def can(_user, "inspector") do
    permit()
    |> read(Item)
    # For now, let's allow access to all subitems for inspector to isolate the issue
    |> all(Subitem)
  end

  def can(%User{id: id} = _user, _) do
    permit()
    |> all(Item, owner_id: id)
  end
end
