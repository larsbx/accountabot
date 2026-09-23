defmodule Accountabot.EngagementTest do
  use ExUnit.Case, async: true
  import Accountabot.Gen
  alias Accountabot.{Engagement, Workflow}

  @cpa {:cpa, "cpa-1"}

  defp run(cmds), do: Enum.reduce(cmds, {nil, []}, &step/2)

  defp step(cmd, {state, log}) do
    {:ok, state, events} = Engagement.handle(state, cmd)
    {state, log ++ events}
  end

  defp open(type \\ :monthly_close),
    do: {:open, %{id: "eng-1", type: type, client: "Mama Woodpecker"}}

  defp accept(state), do: {:resolve, gate_id(state, :accept_engagement), :approve, @cpa}

  defp gate_id(state, kind),
    do:
      state.items
      |> Map.values()
      |> Enum.find(&(&1.kind == kind and &1.status == :open))
      |> Map.fetch!(:id)

  defp item(id, o \\ []),
    do:
      Map.merge(
        %{id: id, kind: :categorize, amount: 10_00, confidence: 0.99, reversible?: true},
        Map.new(o)
      )

  test "opening enters intake with an open engagement-acceptance gate" do
    {s, _} = run([open()])
    assert s.stage == :intake
    assert [%{kind: :accept_engagement, tier: :reserved, status: :open}] = Map.values(s.items)
    assert {:error, {:blocked, [_]}} = Engagement.decide(s, {:advance, :agent})
  end

  test "only the CPA may resolve items" do
    {s, _} = run([open()])

    assert Engagement.decide(s, {:resolve, gate_id(s, :accept_engagement), :approve, :agent}) ==
             {:error, :unauthorized}
  end

  test "auto items apply without blocking; proposed items block until resolved" do
    {s, _} = run([open()])

    {s, _} =
      run_from(s, [
        accept(s),
        {:advance, :agent},
        {:raise, item("a")},
        {:raise, item("p", amount: 5_000_00)}
      ])

    assert s.items["a"].status == :applied
    assert s.items["p"].tier == :propose
    assert {:error, {:blocked, ["p"]}} = Engagement.decide(s, {:advance, :agent})

    {s, _} = run_from(s, [{:resolve, "p", :approve, @cpa}, {:advance, :agent}])
    assert s.stage == :categorize
  end

  test "a rejected gate keeps blocking until a later gate item of that kind is approved" do
    {s, _} = run([open()])
    {s, _} = run_from(s, [{:resolve, gate_id(s, :accept_engagement), :reject, @cpa}])

    assert {:error, {:blocked, [{:gate, :accept_engagement}]}} =
             Engagement.decide(s, {:advance, :agent})

    {s, _} =
      run_from(s, [
        {:raise, item("retry", kind: :accept_engagement)},
        {:resolve, "retry", :approve, @cpa}
      ])

    assert {:ok, _} = Engagement.decide(s, {:advance, :agent})
  end

  test "the CPA can reverse an auto-applied item" do
    {s, _} = run([open()])
    {s, _} = run_from(s, [{:raise, item("a")}, {:resolve, "a", :reject, @cpa}])
    assert s.items["a"].status == :rejected
  end

  test "duplicate item ids are rejected" do
    {s, _} = run([open()])
    {s, _} = run_from(s, [{:raise, item("a")}])
    assert Engagement.decide(s, {:raise, item("a")}) == {:error, {:duplicate_item, "a"}}
  end

  test "advancing past the last stage closes the engagement" do
    s = drive_to_close(:onboarding)
    assert s.status == :closed
    assert Engagement.decide(s, {:advance, :agent}) == {:error, :closed}
  end

  test "state is a pure fold of its events" do
    {s, log} = run([open(:tax_return)])

    {s, log2} =
      run_from(s, [accept(s), {:raise, item("a")}, {:raise, item("b", confidence: 0.1)}])

    assert Engagement.replay(log ++ log2) == s
  end

  test "∀ random histories: every stage gate was CPA-approved before leaving it" do
    check(&engagement_log/0, fn {type, log} -> assert_gates_respected(type, log) end)
  end

  test "items carry evidence keyed by card section; unknown sections are rejected" do
    {s, _} = run([open()])

    ev = %{
      summary: "Coffee at Blue Bottle",
      ledger_impact: [%{"account" => "6100", "debit" => 450}]
    }

    {s, _} = run_from(s, [{:raise, item("a", evidence: ev)}])
    assert s.items["a"].evidence == ev

    assert Engagement.decide(s, {:raise, item("b", evidence: %{gossip: "x"})}) ==
             {:error, {:unknown_evidence, [:gossip]}}
  end

  test "raising an unknown item kind is rejected" do
    {s, _} = run([open()])

    assert Engagement.decide(s, {:raise, item("x", kind: :vibes)}) ==
             {:error, {:unknown_kind, :vibes}}
  end

  # -- helpers --------------------------------------------------------------

  defp run_from(s, cmds), do: Enum.reduce(cmds, {s, []}, &step/2)

  defp drive_to_close(type) do
    Enum.reduce_while(1..100, elem(run([open(type)]), 0), fn _, s ->
      s = approve_open(s)

      case Engagement.handle(s, {:advance, :agent}) do
        {:ok, %{status: :closed} = s, _} -> {:halt, s}
        {:ok, s, _} -> {:cont, s}
      end
    end)
  end

  defp approve_open(s) do
    s.items
    |> Map.values()
    |> Enum.filter(&(&1.status == :open))
    |> Enum.reduce(s, fn i, s ->
      elem(Engagement.handle(s, {:resolve, i.id, :approve, @cpa}), 1)
    end)
  end

  defp assert_gates_respected(type, log) do
    Enum.reduce(log, %{stage: nil, approved: MapSet.new(), kinds: %{}}, fn
      {:entered, next}, acc ->
        if acc.stage,
          do:
            for(
              k <- Workflow.gates(type, acc.stage),
              do:
                assert(
                  MapSet.member?(acc.approved, {acc.stage, k}),
                  "left #{acc.stage} without #{k}"
                )
            )

        %{acc | stage: next}

      {:closed}, acc ->
        for k <- Workflow.gates(type, acc.stage),
            do: assert(MapSet.member?(acc.approved, {acc.stage, k}))

        acc

      {:raised, item}, acc ->
        %{acc | kinds: Map.put(acc.kinds, item.id, item.kind)}

      {:resolved, id, :approve, {:cpa, _}}, acc ->
        %{acc | approved: MapSet.put(acc.approved, {acc.stage, acc.kinds[id]})}

      _, acc ->
        acc
    end)
  end
end
