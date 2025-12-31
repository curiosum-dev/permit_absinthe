defmodule PermitAbsintheDemo.User do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:role, Ecto.Enum, values: [:admin, :user], default: :user)

    has_many(:notes, PermitAbsintheDemo.Note, foreign_key: :owner_id)

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:role])
  end
end
