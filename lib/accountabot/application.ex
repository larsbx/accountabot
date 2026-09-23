defmodule Accountabot.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        {Phoenix.PubSub, name: Accountabot.PubSub},
        store_child(Application.fetch_env!(:accountabot, :store)),
        AccountabotWeb.Endpoint
      ]

    with {:ok, pid} <-
           Supervisor.start_link(children, strategy: :one_for_one, name: Accountabot.Supervisor) do
      if cpa = Application.get_env(:accountabot, :seed_demo),
        do: Accountabot.Demo.seed(Accountabot.store(), cpa)

      {:ok, pid}
    end
  end

  # Postgrex fills unset options from PGHOST, PGUSER, PGPASSWORD and PGDATABASE.
  defp store_child(:postgres),
    do: {Postgrex, Keyword.put(Application.get_env(:accountabot, :db, []), :name, Accountabot.DB)}

  defp store_child(:memory), do: {Accountabot.EventStore.Memory, name: Accountabot.MemoryStore}
end
