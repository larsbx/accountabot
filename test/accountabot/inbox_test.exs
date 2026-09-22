defmodule Accountabot.InboxTest do
  use ExUnit.Case, async: true
  alias Accountabot.{Engagement, Inbox}

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

  test "routes by tier: reserved → dashboard+sms, propose → dashboard+digest, auto → digest" do
    assert Inbox.channels(%{tier: :reserved, status: :open}) == [:dashboard, :sms]
    assert Inbox.channels(%{tier: :propose, status: :open}) == [:dashboard, :digest]
    assert Inbox.channels(%{tier: :auto, status: :applied}) == [:digest]
    assert Inbox.channels(%{tier: :propose, status: :approved}) == []
  end

  test "queue lists open items, reserved first, then by amount desc" do
    engs = [
      eng("e1", [%{id: "small", amount: 2_000_00}]),
      eng("e2", [%{id: "big", amount: 9_000_00}, %{id: "auto", amount: 1_00}])
    ]

    assert Inbox.queue(engs, :dashboard)
           |> Enum.map(fn {e, i} -> {e, i.kind == :accept_engagement || i.id} end) ==
             [{"e1", true}, {"e2", true}, {"e2", "big"}, {"e1", "small"}]

    assert Enum.any?(Inbox.queue(engs, :digest), &match?({"e2", %{id: "auto"}}, &1))
    assert Enum.all?(Inbox.queue(engs, :sms), fn {_, i} -> i.tier == :reserved end)
  end
end
