defmodule PermitAbsintheDemo.Authorization do
  @moduledoc false
  use Permit.Ecto,
    permissions_module: PermitAbsintheDemo.Permissions,
    repo: PermitAbsintheDemo.Repo
end
