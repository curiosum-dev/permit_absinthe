defmodule PermitAbsintheDemo.Permissions do
  @moduledoc false
  use Permit.Ecto.Permissions, actions_module: PermitAbsintheDemo.Actions

  alias PermitAbsintheDemo.{Note, User}

  def can(%User{role: :admin}) do
    permit()
    |> all(Note)
  end

  def can(%User{id: id, role: :user}) do
    permit()
    |> all(Note, owner_id: id)
  end

  def can(_user), do: permit()
end
