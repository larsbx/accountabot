defmodule Accountabot.EventStore.Memory do
  @moduledoc "In-process adapter for tests and local runs. Round-trips data through JSON like Postgres does."

  @behaviour Accountabot.EventStore
  use Agent

  def start_link(opts \\ []), do: Agent.start_link(fn -> %{} end, opts)

  @impl true
  def read(srv, stream) do
    rs = Agent.get(srv, &Map.get(&1, stream, []))
    {:ok, rs, length(rs)}
  end

  @impl true
  def append(srv, stream, expected, records) do
    stored =
      Enum.map(records, &%{type: &1.type, data: &1.data |> Jason.encode!() |> Jason.decode!()})

    Agent.get_and_update(srv, fn streams ->
      case Map.get(streams, stream, []) do
        rs when length(rs) == expected ->
          {{:ok, expected + length(stored)}, Map.put(streams, stream, rs ++ stored)}

        _ ->
          {{:error, :wrong_expected_version}, streams}
      end
    end)
  end
end
