defmodule Accountabot.EventStoreContract do
  @moduledoc "Shared behavioural tests every `Accountabot.EventStore` adapter must pass."

  defmacro __using__(opts) do
    quote do
      alias Accountabot.EventStore

      setup do
        {:ok,
         store: unquote(opts[:store]).(),
         stream: "s-#{Base.encode16(:crypto.strong_rand_bytes(8))}"}
      end

      defp rec(n), do: %{type: "t#{n}", data: %{"n" => n, "nested" => %{"k" => [1, "two"]}}}

      test "an unknown stream reads as empty at version 0", %{store: st, stream: s} do
        assert EventStore.read(st, s) == {:ok, [], 0}
      end

      test "appends at the expected version and reads back in order", %{store: st, stream: s} do
        assert EventStore.append(st, s, 0, [rec(1), rec(2)]) == {:ok, 2}
        assert EventStore.append(st, s, 2, [rec(3)]) == {:ok, 3}
        assert EventStore.read(st, s) == {:ok, [rec(1), rec(2), rec(3)], 3}
      end

      test "rejects a stale expected version without writing", %{store: st, stream: s} do
        {:ok, 1} = EventStore.append(st, s, 0, [rec(1)])
        assert EventStore.append(st, s, 0, [rec(2)]) == {:error, :wrong_expected_version}
        assert EventStore.append(st, s, 5, [rec(2)]) == {:error, :wrong_expected_version}
        assert EventStore.read(st, s) == {:ok, [rec(1)], 1}
      end

      test "streams are isolated", %{store: st, stream: s} do
        {:ok, 1} = EventStore.append(st, s, 0, [rec(1)])
        assert EventStore.read(st, s <> "-other") == {:ok, [], 0}
      end

      test "∀ concurrent writers at the same version: exactly one wins", %{store: st, stream: s} do
        results =
          1..8
          |> Task.async_stream(fn n -> EventStore.append(st, s, 0, [rec(n)]) end,
            max_concurrency: 8
          )
          |> Enum.map(fn {:ok, r} -> r end)

        assert Enum.count(results, &(&1 == {:ok, 1})) == 1
        assert Enum.count(results, &(&1 == {:error, :wrong_expected_version})) == 7
        assert {:ok, [_], 1} = EventStore.read(st, s)
      end
    end
  end
end
