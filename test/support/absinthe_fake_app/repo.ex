defmodule Permit.AbsintheFakeApp.Repo do
  use Ecto.Repo,
    otp_app: :permit_absinthe,
    adapter: Ecto.Adapters.Postgres

  alias Permit.AbsintheFakeApp.{Item, Repo, Subitem, User}

  def seed_data! do
    users = [
      %User{id: 1, roles: ["admin"]} |> Repo.insert!(),
      %User{id: 2, roles: ["owner"]} |> Repo.insert!(),
      %User{id: 3, roles: ["inspector"]} |> Repo.insert!()
    ]

    items = [
      %Item{id: 1, owner_id: 1, permission_level: 1} |> Repo.insert!(),
      %Item{id: 2, owner_id: 2, permission_level: 2, thread_name: "dmt"} |> Repo.insert!(),
      %Item{id: 3, owner_id: 3, permission_level: 3} |> Repo.insert!()
    ]

    subitems = [
      %Subitem{id: 1, item_id: 1, name: "subitem 1"} |> Repo.insert!(),
      %Subitem{id: 2, item_id: 1, name: "subitem 2"} |> Repo.insert!(),
      %Subitem{id: 3, item_id: 2, name: "subitem 3"} |> Repo.insert!(),
      %Subitem{id: 4, item_id: 2, name: "subitem 4"} |> Repo.insert!(),
      %Subitem{id: 5, item_id: 3, name: "subitem 5"} |> Repo.insert!(),
      %Subitem{id: 6, item_id: 3, name: "subitem 6"} |> Repo.insert!()
    ]

    %{users: users, items: items, subitems: subitems}
  end
end
