defmodule Permit.AbsintheFakeApp.Subitem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "subitems" do
    field(:name, :string)

    belongs_to(:item, Permit.AbsintheFakeApp.Item, foreign_key: :item_id)

    timestamps()
  end

  def changeset(subitem, attrs) do
    subitem
    |> cast(attrs, [:name, :item_id])
  end
end
