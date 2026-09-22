defmodule Accountabot.Migrator do
  @moduledoc """
  Applies pending `Accountabot.Migrations` in one transaction under a
  transaction-scoped advisory lock: concurrent runners serialise, and a failed
  run leaves the schema untouched. Idempotent.
  """

  alias Accountabot.Migrations

  @doc "Returns `{:ok, [applied_version]}`."
  def run(conn) do
    Postgrex.transaction(conn, fn c ->
      q = &Postgrex.query!(c, &1, &2)
      q.("SELECT pg_advisory_xact_lock(hashtext('accountabot_migrations'))", [])

      q.(
        "CREATE TABLE IF NOT EXISTS schema_migrations (version integer PRIMARY KEY, name text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now())",
        []
      )

      done =
        q.("SELECT version FROM schema_migrations", []).rows |> List.flatten() |> MapSet.new()

      for {v, name, stmts} <- Migrations.all(), v not in done do
        Enum.each(stmts, &q.(&1, []))
        q.("INSERT INTO schema_migrations (version, name) VALUES ($1, $2)", [v, name])
        v
      end
    end)
  end
end
