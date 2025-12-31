alias PermitAbsintheDemo.{Note, Repo, User}

alice = Repo.insert!(%User{id: 1, role: :user})
bob = Repo.insert!(%User{id: 2, role: :user})
admin = Repo.insert!(%User{id: 3, role: :admin})

notes = [
  %Note{id: 1, owner_id: alice.id, body: "alice's first note"},
  %Note{id: 2, owner_id: alice.id, body: "alice's second note"},
  %Note{id: 3, owner_id: alice.id, body: "alice's soft deleted note", deleted_at: DateTime.truncate(DateTime.utc_now(), :second)},
  %Note{id: 4, owner_id: bob.id, body: "bob's first note"}
]

Enum.each(notes, &Repo.insert!/1)

IO.puts("Seeded users and notes.")
