defmodule Accountabot.CpasTest do
  use ExUnit.Case, async: true
  alias Accountabot.{Cpas, EventStore}

  setup do
    {:ok, store: {EventStore.Memory, start_supervised!(EventStore.Memory)}}
  end

  test "onboarding persists answer by answer and yields a profile", %{store: st} do
    assert %{id: :surfaces} = Cpas.next_question(st, "cpa-1")
    assert {:error, {:incomplete, :surfaces}} = Cpas.profile(st, "cpa-1")

    for {q, v} <- [
          surfaces: [:web, :mobile],
          evidence: [:summary],
          cadence: :daily,
          interrupt: :no,
          autonomy: :cautious
        ] do
      assert {:ok, _, _} = Cpas.answer(st, "cpa-1", q, v)
    end

    assert Cpas.next_question(st, "cpa-1") == :done

    assert {:ok, %{notify: %{reserved: {:digest, :web}}, digest: :daily}} =
             Cpas.profile(st, "cpa-1")
  end

  test "revising an answer adapts the profile and keeps the history", %{store: st} do
    for {q, v} <- [
          surfaces: [:web, :mobile],
          evidence: [:summary],
          cadence: :daily,
          interrupt: :no,
          autonomy: :cautious
        ],
        do: Cpas.answer(st, "cpa-1", q, v)

    {:ok, _, _} = Cpas.answer(st, "cpa-1", :interrupt, :yes)
    assert {:ok, %{notify: %{reserved: {:now, :mobile}}}} = Cpas.profile(st, "cpa-1")
    assert {:ok, events, 6} = EventStore.read(st, "cpa-cpa-1")
    assert length(events) == 6
  end

  test "invalid answers write nothing", %{store: st} do
    assert {:error, {:invalid_answer, :cadence}} = Cpas.answer(st, "cpa-1", :cadence, :hourly)
    assert EventStore.read(st, "cpa-cpa-1") == {:ok, [], 0}
  end
end
