defmodule Permit.AbsintheFakeApp.Migrations do
  @moduledoc """
  Migrations for setting up test database tables.
  """
  use Ecto.Migration

  def change do
    create table(:users) do
      add(:permission_level, :integer)
      add(:roles, {:array, :string})

      timestamps()
    end

    create table(:items) do
      add(:permission_level, :integer)
      add(:thread_name, :string)
      add(:owner_id, references(:users))

      timestamps()
    end

    create table(:subitems) do
      add(:name, :string)
      add(:item_id, references(:items))

      timestamps()
    end
  end
end
