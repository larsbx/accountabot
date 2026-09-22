defmodule Accountabot.Application do
  @moduledoc false
  use Application

  # Starts the `Accountabot.DB` pool only when `config :accountabot, :db` is set.
  # Postgrex fills unset options from PGHOST, PGUSER, PGPASSWORD and PGDATABASE.
  @impl true
  def start(_type, _args) do
    children =
      case Application.get_env(:accountabot, :db) do
        nil -> []
        opts -> [{Postgrex, Keyword.put(opts, :name, Accountabot.DB)}]
      end

    Supervisor.start_link(children, strategy: :one_for_one, name: Accountabot.Supervisor)
  end
end
