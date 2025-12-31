defmodule PermitAbsintheDemo.Note do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "notes" do
    field(:body, :string)
    field(:deleted_at, :utc_datetime)

    belongs_to(:user, PermitAbsintheDemo.User, foreign_key: :owner_id)

    timestamps()
  end

  def changeset(note, attrs) do
    note
    |> cast(attrs, [:body, :owner_id, :deleted_at])
  end
end
