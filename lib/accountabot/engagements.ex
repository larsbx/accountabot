defmodule Accountabot.Engagements do
  @moduledoc "Engagement repository: `Accountabot.Aggregate` over stream `engagement-<id>`."

  alias Accountabot.{Aggregate, Engagement}

  def load(store, id), do: with({:ok, s, _} <- Aggregate.load(store, spec(id)), do: {:ok, s})

  def execute(_, id, {:open, %{id: other}}) when other != id, do: {:error, :id_mismatch}
  def execute(store, id, cmd), do: Aggregate.execute(store, spec(id), cmd)

  defp spec(id), do: %{decider: Engagement, codec: Engagement.Codec, stream: "engagement-#{id}"}
end
