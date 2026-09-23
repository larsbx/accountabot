defmodule Accountabot.InboxTest do
  use ExUnit.Case, async: true
  alias Accountabot.{Engagement, Inbox, Profile}

  @answers %{
    surfaces: [:web, :sms],
    evidence: [:ledger_impact],
    cadence: :weekly,
    interrupt: :yes,
    autonomy: :balanced
  }

  setup do
    {:ok, profile} = Profile.from_answers(@answers)
    {:ok, profile: profile}
  end

  defp eng(id, raises) do
    {:ok, s, _} = Engagement.handle(nil, {:open, %{id: id, type: :monthly_close, client: id}})

    Enum.reduce(raises, s, fn r, s ->
      {:ok, s, _} =
        Engagement.handle(
          s,
          {:raise, Map.merge(%{confidence: 0.99, reversible?: true, kind: :categorize}, r)}
        )

      s
    end)
  end

  test "notification follows the CPA's profile; settled items are silent", %{profile: p} do
    assert Inbox.notification(%{tier: :reserved, status: :open}, p) == {:now, :sms}
    assert Inbox.notification(%{tier: :propose, status: :open}, p) == {:digest, :web}
    assert Inbox.notification(%{tier: :auto, status: :applied}, p) == {:digest, :web}
    assert Inbox.notification(%{tier: :propose, status: :approved}, p) == :none
  end

  test "queue lists open items, reserved first, then by amount desc", %{profile: p} do
    engs = [
      eng("e1", [%{id: "small", amount: 2_000_00}]),
      eng("e2", [%{id: "big", amount: 9_000_00}, %{id: "auto", amount: 1_00}])
    ]

    assert Inbox.queue(engs)
           |> Enum.map(fn {e, i} -> {e, i.kind == :accept_engagement || i.id} end) ==
             [{"e1", true}, {"e2", true}, {"e2", "big"}, {"e1", "small"}]

    assert Enum.all?(Inbox.alerts(engs, p), fn {_, i} -> i.tier == :reserved end)
    assert Enum.any?(Inbox.digest(engs, p), &match?({"e2", %{id: "auto"}}, &1))
  end

  test "cards carry exactly the sections the CPA asked for", %{profile: p} do
    [{_, item} | _] = Inbox.queue([eng("e1", [])])
    assert %{sections: [:summary, :ledger_impact], tier: :reserved} = Inbox.card(item, p)
  end
end
