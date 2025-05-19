defmodule Permit.AbsintheFakeApp.Authorization do
  alias Permit.AbsintheFakeApp.{Permissions, Repo}

  use Permit.Ecto,
    permissions_module: Permissions,
    repo: Repo
end
