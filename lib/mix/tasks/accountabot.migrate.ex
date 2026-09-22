defmodule Mix.Tasks.Accountabot.Migrate do
  @shortdoc "Applies pending database migrations"
  @moduledoc "Applies pending migrations to `Accountabot.DB` (configured via PG* env vars)."
  use Mix.Task

  @requirements ["app.start"]

  @impl true
  def run(_) do
    {:ok, applied} = Accountabot.Migrator.run(Accountabot.DB)
    Mix.shell().info("applied: #{inspect(applied)}")
  end
end
