defmodule PermitAbsintheDemo.Repo.Migrations.CreateDemoTables do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :role, :string, null: false, default: "user"

      timestamps()
    end

    create table(:notes) do
      add :body, :string
      add :owner_id, references(:users)
      add :deleted_at, :utc_datetime

      timestamps()
    end

    create index(:notes, [:owner_id])
  end
end
