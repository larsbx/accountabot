defmodule Accountabot.Engagements do
  @moduledoc """
  Engagement repository over an `Accountabot.EventStore`.

      load(id)         = replay(decode(read(stream(id))))
      execute(id, cmd) = decide(load(id), cmd), appended at the version it was loaded from

  On a concurrent write the command is re-decided against fresh state, so it
  is validated against what is actually stored, never a stale snapshot.
  """

  alias Accountabot.{Engagement, EventStore}
  alias Accountabot.Engagement.Codec

  @retries 5

  def load(store, id) do
    with {:ok, state, _} <- load_versioned(store, id), do: {:ok, state}
  end

  def execute(store, id, cmd, retries \\ @retries)

  def execute(_, id, {:open, %{id: other}}, _) when other != id, do: {:error, :id_mismatch}

  def execute(store, id, cmd, retries) do
    with {:ok, state, version} <- load_versioned(store, id),
         {:ok, new_state, events} <- Engagement.handle(state, cmd) do
      case EventStore.append(store, stream(id), version, Enum.map(events, &Codec.encode/1)) do
        {:ok, _} -> {:ok, new_state, events}
        {:error, :wrong_expected_version} when retries > 0 -> execute(store, id, cmd, retries - 1)
        error -> error
      end
    end
  end

  defp load_versioned(store, id) do
    {:ok, records, version} = EventStore.read(store, stream(id))
    {:ok, records |> Enum.map(&Codec.decode/1) |> Engagement.replay(), version}
  end

  defp stream(id), do: "engagement-#{id}"
end
