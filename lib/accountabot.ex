defmodule Accountabot do
  @moduledoc "Entry points shared by the web layer and tasks."

  @doc "The configured event store: Postgres in production, in-memory in dev and test."
  def store do
    case Application.fetch_env!(:accountabot, :store) do
      :postgres -> {Accountabot.EventStore.Postgres, Accountabot.DB}
      :memory -> {Accountabot.EventStore.Memory, Accountabot.MemoryStore}
    end
  end
end
