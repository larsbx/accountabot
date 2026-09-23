defmodule AccountabotWeb.ReviewLiveTest do
  use AccountabotWeb.ConnCase, async: true
  alias Accountabot.{Demo, Engagements, Practice}

  @answers [surfaces: [:web], evidence: [:ledger_impact], cadence: :weekly, autonomy: :balanced]

  test "sends an un-onboarded CPA to onboarding", %{conn: conn, cpa: cpa} do
    assert {:error, {:live_redirect, %{to: to}}} = live(conn, ~p"/review/#{cpa}")
    assert to == "/onboarding/#{cpa}"
  end

  test "groups work by who must act and shows only the chosen sections", %{conn: conn, cpa: cpa} do
    onboard(cpa, @answers)
    :ok = Demo.seed(Accountabot.store(), cpa)
    {:ok, _view, html} = live(conn, ~p"/review/#{cpa}")

    assert html =~ "This week&#39;s review"
    assert html =~ "Only you can decide"
    assert html =~ "Accrue September rent"
    assert html =~ "Ledger impact"
    refute html =~ "My reasoning" or html =~ "Agent reasoning"
    assert html =~ "Done on my own"
  end

  test "approving removes the item from the queue and is recorded as the CPA", %{
    conn: conn,
    cpa: cpa
  } do
    onboard(cpa, @answers)
    :ok = Demo.seed(Accountabot.store(), cpa)
    {:ok, view, _} = live(conn, ~p"/review/#{cpa}")

    eid = "#{cpa}-close-2026-09"
    view |> element("#item-#{eid}-je-rent-accrual button", "Approve") |> render_click()
    refute has_element?(view, "#item-#{eid}-je-rent-accrual")

    {:ok, e} = Engagements.load(Accountabot.store(), eid)
    assert e.items["je-rent-accrual"].status == :approved
  end

  test "reversing an auto-applied item", %{conn: conn, cpa: cpa} do
    onboard(cpa, @answers)
    :ok = Demo.seed(Accountabot.store(), cpa)
    {:ok, view, _} = live(conn, ~p"/review/#{cpa}")

    view |> element("#item-#{cpa}-close-2026-09-cat-flour button", "Reverse") |> render_click()
    refute has_element?(view, "#item-#{cpa}-close-2026-09-cat-flour")
  end

  test "updates live when the agent raises new work", %{conn: conn, cpa: cpa} do
    onboard(cpa, @answers)
    :ok = Demo.seed(Accountabot.store(), cpa)
    {:ok, view, _} = live(conn, ~p"/review/#{cpa}")

    {:ok, _, _} =
      Practice.raise_item(Accountabot.store(), "#{cpa}-close-2026-09", %{
        id: "wo-bad-debt",
        kind: :write_off,
        amount: 640_00,
        confidence: 0.8,
        reversible?: false,
        evidence: %{summary: "Write off invoice #1182 (customer closed)"}
      })

    assert render(view) =~ "Write off invoice #1182"
  end

  test "a CPA cannot resolve another CPA's items", %{cpa: cpa} do
    onboard(cpa, @answers)
    :ok = Demo.seed(Accountabot.store(), cpa)

    assert Practice.resolve(
             Accountabot.store(),
             "someone-else",
             "#{cpa}-close-2026-09",
             "je-rent-accrual",
             :approve
           ) ==
             {:error, :not_found}
  end
end
