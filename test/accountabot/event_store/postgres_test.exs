defmodule Accountabot.EventStore.PostgresTest do
  use ExUnit.Case, async: true
  @moduletag :postgres

  use Accountabot.EventStoreContract,
    store: fn -> {Accountabot.EventStore.Postgres, Accountabot.TestDB} end

  test "events are append-only at the database level", %{stream: s} do
    {:ok, 1} =
      Accountabot.EventStore.append({Accountabot.EventStore.Postgres, Accountabot.TestDB}, s, 0, [
        rec(1)
      ])

    for sql <- [
          "UPDATE events SET type = 'x' WHERE stream_id = $1",
          "DELETE FROM events WHERE stream_id = $1"
        ] do
      assert {:error, %Postgrex.Error{postgres: %{message: "append-only table" <> _}}} =
               Postgrex.query(Accountabot.TestDB, sql, [s])
    end
  end
end
