ExUnit.start()

# We'll setup our fake app database here, but the actual repo
# will be started in individual test setup blocks
{:ok, _} = Application.ensure_all_started([:ecto_sql, :postgrex, :absinthe])
