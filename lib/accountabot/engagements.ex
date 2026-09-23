defmodule Accountabot.Engagements do
  @moduledoc "Engagement repository: `Accountabot.Aggregate` over stream `engagement-<id>`."

  alias Accountabot.{Aggregate, Engagement, EventStore}

  @prefix "engagement-"

  def load(store, id), do: with({:ok, s, _} <- Aggregate.load(store, spec(id)), do: {:ok, s})

  def execute(_, id, {:open, %{id: other}}) when other != id, do: {:error, :id_mismatch}
  def execute(store, id, cmd), do: Aggregate.execute(store, spec(id), cmd)

  @doc "All engagements supervised by `cpa_id`. A full scan for now; a projection replaces it at scale."
  def for_cpa(store, cpa_id) do
    for stream <- EventStore.streams(store, @prefix),
        {:ok, %Engagement{cpa_id: ^cpa_id} = e} <- [
          load(store, String.replace_prefix(stream, @prefix, ""))
        ],
        do: e
  end

  defp spec(id), do: %{decider: Engagement, codec: Engagement.Codec, stream: @prefix <> id}
end
