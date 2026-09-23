defmodule Accountabot.ProfileTest do
  use ExUnit.Case, async: true
  import Accountabot.Gen
  alias Accountabot.{Onboarding, Policy, Profile}

  @base %{
    surfaces: [:web, :sms],
    evidence: [:ledger_impact],
    cadence: :weekly,
    interrupt: :yes,
    autonomy: :balanced
  }

  test "incomplete onboarding names the next question" do
    assert Profile.from_answers(%{surfaces: [:web]}) == {:error, {:incomplete, :evidence}}
  end

  test "interrupting CPA: reserved now via the most direct surface, proposals in the digest" do
    {:ok, p} = Profile.from_answers(@base)
    assert p.notify == %{reserved: {:now, :sms}, propose: {:digest, :web}, auto: {:digest, :web}}
    assert p.digest == :weekly
  end

  test "real-time CPA gets proposals immediately; digest via email when chosen" do
    {:ok, p} =
      Profile.from_answers(
        %{@base | cadence: :realtime, surfaces: [:web, :email]}
        |> Map.delete(:interrupt)
      )

    assert p.notify.propose == {:now, :email}
    assert p.notify.reserved == {:now, :email}
    assert p.notify.auto == {:digest, :email}
    assert p.digest == :daily
  end

  test "cards always lead with a summary, then the evidence the CPA asked for" do
    {:ok, p} = Profile.from_answers(%{@base | evidence: [:source_documents, :agent_reasoning]})
    assert p.card_sections == [:summary, :source_documents, :agent_reasoning]
  end

  test "describe/1 explains the derived behaviour in plain language" do
    {:ok, p} = Profile.from_answers(@base)

    assert Profile.describe(p) == [
             "Sign-offs, filings and other decisions only you can make: sent to you right away by SMS.",
             "Proposed entries and adjustments: collected in your weekly digest on the web.",
             "Routine work I do on my own: listed in your weekly digest on the web, where you can reverse it.",
             "I act alone only below $1,000.00 and at ≥ 95% confidence; everything else waits for you.",
             "Each item shows: summary, ledger impact."
           ]
  end

  test "autonomy answer sets the agent's policy" do
    for level <- [:cautious, :balanced, :hands_off] do
      {:ok, p} = Profile.from_answers(%{@base | autonomy: level})
      assert p.policy == Profile.policy_for(level)
    end
  end

  test "∀ complete answers: reserved work is never silent and every route uses a chosen surface" do
    check(&random_answers/0, fn a ->
      {:ok, p} = Profile.from_answers(a)
      assert {_, _} = p.notify.reserved
      for {_, {_, via}} <- p.notify, do: assert(via in a.surfaces)

      interrupter = Enum.find([:mobile, :sms, :email], &(&1 in a.surfaces))
      wants_now = a.cadence == :realtime or Map.get(a, :interrupt) == :yes
      if wants_now and interrupter, do: assert(p.notify.reserved == {:now, interrupter})
    end)
  end

  test "∀ actions: autonomy is monotone — cautious ⊆ balanced ⊆ hands_off" do
    [c, b, h] = Enum.map([:cautious, :balanced, :hands_off], &Profile.policy_for/1)
    kinds = Policy.kinds()

    gen = fn ->
      %{
        kind: one_of(kinds),
        amount: int(0, 10_000_00),
        confidence: float01(),
        reversible?: bool()
      }
    end

    check(gen, fn a ->
      if Policy.classify(a, c) == :auto, do: assert(Policy.classify(a, b) == :auto)
      if Policy.classify(a, b) == :auto, do: assert(Policy.classify(a, h) == :auto)
    end)
  end

  defp random_answers do
    Enum.reduce_while(1..10, %{}, fn _, a ->
      case Onboarding.next(a) do
        :done ->
          {:halt, a}

        q ->
          v =
            if q.type == :multi,
              do: Enum.take_random(q.options, int(1, length(q.options))),
              else: one_of(q.options)

          {:cont, Map.put(a, q.id, v)}
      end
    end)
  end
end
