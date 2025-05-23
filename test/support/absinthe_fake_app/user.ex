defmodule Permit.AbsintheFakeApp.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:permission_level, :integer)
    field(:roles, {:array, :string})

    has_many(:item, Permit.AbsintheFakeApp.Item, foreign_key: :owner_id)

    timestamps()
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:permission_level, :roles])
  end
end
