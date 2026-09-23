defmodule Accountabot.Aggregate do
  @moduledoc """
  Runs a `Decider` against an `EventStore` stream.

      load(spec)         = replay(decode(read(stream)))
      execute(spec, cmd) = decide(load(spec), cmd), appended at the version it was loaded from

  After a concurrent write the command is decided again against fresh state.
  `spec` is `%{decider: module, codec: module, stream: String.t()}`.
  """

  alias Accountabot.EventStore

  @retries 5

  def load(store, %{decider: d, codec: c, stream: s}) do
    {:ok, records, version} = EventStore.read(store, s)
    {:ok, records |> Enum.map(&c.decode/1) |> d.replay(), version}
  end

  def execute(store, spec, cmd, retries \\ @retries) do
    with {:ok, state, version} <- load(store, spec),
         {:ok, new_state, events} <- spec.decider.handle(state, cmd) do
      case EventStore.append(store, spec.stream, version, Enum.map(events, &spec.codec.encode/1)) do
        {:ok, _} ->
          {:ok, new_state, events}

        {:error, :wrong_expected_version} when retries > 0 ->
          execute(store, spec, cmd, retries - 1)

        error ->
          error
      end
    end
  end
end
