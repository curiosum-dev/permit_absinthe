defmodule Permit.AbsintheFakeApp.Setup do
  @moduledoc """
  Setup module for initializing the test environment.
  """

  alias Permit.AbsintheFakeApp.{Migrations, Repo}

  @doc """
  Sets up the repository and migrations for the test environment.
  Should be called in test setup or in test_helper.exs
  """
  def setup_test_db do
    # Create and migrate database
    {:ok, _} = Ecto.Adapters.Postgres.ensure_all_started(Repo, :temporary)
    _ = Repo.__adapter__().storage_down(Repo.config())
    :ok = Repo.__adapter__().storage_up(Repo.config())

    # Start the repo
    {:ok, _pid} = Repo.start_link()

    # Run migrations
    Ecto.Migrator.up(Repo, 0, Migrations, log: false)

    # Put repo into sandbox mode for tests
    Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)

    :ok
  end
end
