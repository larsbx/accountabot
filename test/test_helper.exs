db = [
  name: Accountabot.TestDB,
  hostname: System.get_env("PGHOST", "localhost"),
  username: System.get_env("PGUSER", "postgres"),
  password: System.get_env("PGPASSWORD", "postgres"),
  database: System.get_env("PGDATABASE", "accountabot_test"),
  pool_size: 4
]

{:ok, pool} = Postgrex.start_link(db)

exclude =
  try do
    {:ok, _} = Accountabot.Migrator.run(Accountabot.TestDB)
    []
  rescue
    e ->
      Logger.configure(level: :none)
      GenServer.stop(pool)

      IO.puts(
        :stderr,
        "⚠ Postgres unavailable (#{Exception.message(e)}); excluding :postgres tests"
      )

      [:postgres]
  end

ExUnit.start(exclude: exclude)
