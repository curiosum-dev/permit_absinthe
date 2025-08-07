defmodule Permit.AbsintheFakeApp.Authorization do
  @moduledoc false
  alias Permit.AbsintheFakeApp.{Permissions, Repo}

  use Permit.Ecto,
    permissions_module: Permissions,
    repo: Repo
end
