defmodule Accountabot.PolicyTest do
  use ExUnit.Case, async: true
  import Accountabot.Gen
  alias Accountabot.Policy

  @cfg Policy.config(materiality: 1_000_00, min_confidence: 0.95)

  defp action(overrides),
    do:
      Map.merge(
        %{kind: :categorize, amount: 50_00, confidence: 0.99, reversible?: true},
        Map.new(overrides)
      )

  test "routine, small, confident, reversible → auto" do
    assert Policy.classify(action([]), @cfg) == :auto
  end

  test "each failed auto condition demotes to propose" do
    for o <- [
          [amount: 1_000_00],
          [confidence: 0.94],
          [reversible?: false],
          [kind: :adjusting_entry]
        ] do
      assert Policy.classify(action(o), @cfg) == :propose, inspect(o)
    end
  end

  test "reserved kinds are reserved regardless of other attributes" do
    for k <- Policy.reserved_kinds() do
      assert Policy.classify(action(kind: k, amount: 0, confidence: 1.0), @cfg) == :reserved
    end
  end

  test "∀ actions: auto ⇒ allowlisted ∧ amount < materiality ∧ confidence ≥ min ∧ reversible" do
    kinds = Policy.reserved_kinds() ++ Policy.auto_kinds() ++ [:adjusting_entry, :unknown]

    gen = fn ->
      action(
        kind: one_of(kinds),
        amount: int(0, 5_000_00),
        confidence: float01(),
        reversible?: bool()
      )
    end

    check(gen, fn a ->
      if Policy.classify(a, @cfg) == :auto do
        assert a.kind in Policy.auto_kinds()

        assert a.amount < @cfg.materiality and a.confidence >= @cfg.min_confidence and
                 a.reversible?
      end

      if a.kind in Policy.reserved_kinds(), do: assert(Policy.classify(a, @cfg) == :reserved)
    end)
  end
end
