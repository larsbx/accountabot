defmodule Accountabot.EngagementsTest do
  use ExUnit.Case, async: true
  alias Accountabot.{Engagements, EventStore}

  @cpa {:cpa, "cpa-1"}

  setup do
    {:ok, store: {EventStore.Memory, start_supervised!(EventStore.Memory)}}
  end

  defp open(store, id),
    do: Engagements.execute(store, id, {:open, %{id: id, type: :monthly_close, client: "c"}})

  test "execute persists; load replays to the same state", %{store: st} do
    {:ok, _, _} = open(st, "e1")

    {:ok, s, _} =
      Engagements.execute(st, "e1", {:resolve, "intake:accept_engagement", :approve, @cpa})

    {:ok, s2, _} = Engagements.execute(st, "e1", {:advance, :agent})

    assert s.items["intake:accept_engagement"].status == :approved
    assert {:ok, ^s2} = Engagements.load(st, "e1")
    assert s2.stage == :gather
  end

  test "domain errors write nothing", %{store: st} do
    {:ok, _, _} = open(st, "e1")
    {:ok, [_ | _] = before, v} = EventStore.read(st, "engagement-e1")
    assert {:error, {:blocked, _}} = Engagements.execute(st, "e1", {:advance, :agent})
    assert EventStore.read(st, "engagement-e1") == {:ok, before, v}
  end

  test "an open command must name its own stream", %{store: st} do
    assert Engagements.execute(st, "e1", {:open, %{id: "e2", type: :monthly_close, client: "c"}}) ==
             {:error, :id_mismatch}
  end

  test "concurrent commands serialise: each is re-decided against fresh state", %{store: st} do
    {:ok, _, _} = open(st, "e1")

    raises =
      for n <- 1..6,
          do:
            {:raise,
             %{id: "i#{n}", kind: :categorize, amount: 1_00, confidence: 0.99, reversible?: true}}

    results =
      raises |> Task.async_stream(&Engagements.execute(st, "e1", &1)) |> Enum.map(&elem(&1, 1))

    assert Enum.all?(results, &match?({:ok, _, _}, &1))
    {:ok, s} = Engagements.load(st, "e1")
    assert Enum.all?(1..6, &Map.has_key?(s.items, "i#{&1}"))
  end
end
