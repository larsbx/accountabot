defmodule AccountabotWeb.OnboardingLiveTest do
  use AccountabotWeb.ConnCase, async: true

  defp answer(view, value), do: view |> form("#question", %{"value" => value}) |> render_submit()

  test "walks the CPA through the questions and explains the result", %{conn: conn, cpa: cpa} do
    {:ok, view, html} = live(conn, ~p"/onboarding/#{cpa}")
    assert html =~ "Where do you want to review the agent&#39;s work?"
    assert html =~ "Question 1 of"

    answer(view, ["web", "sms"])
    answer(view, ["summary", "ledger_impact"])
    answer(view, "weekly")
    assert render(view) =~ "interrupt you right away"
    answer(view, "yes")
    html = answer(view, "balanced")

    assert html =~ "Here&#39;s how I&#39;ll work with you"
    assert html =~ "sent to you right away by SMS"
    assert html =~ "Each item shows: summary, ledger impact."
  end

  test "an empty multi-select is refused with a message, nothing stored", %{conn: conn, cpa: cpa} do
    {:ok, view, _} = live(conn, ~p"/onboarding/#{cpa}")
    assert view |> element("#question") |> render_submit(%{}) =~ "Pick at least one."
    assert Accountabot.Cpas.answers(Accountabot.store(), cpa) == %{}
  end

  test "changing an answer adapts the plan, and newly relevant questions are asked", %{
    conn: conn,
    cpa: cpa
  } do
    onboard(cpa,
      surfaces: [:web, :sms],
      evidence: [:summary],
      cadence: :realtime,
      autonomy: :balanced
    )

    {:ok, view, html} = live(conn, ~p"/onboarding/#{cpa}")
    assert html =~ "Proposed entries and adjustments: sent to you right away"

    view |> element("button[phx-value-q=cadence]") |> render_click()
    answer(view, "weekly")
    assert render(view) =~ "interrupt you right away"
    html = answer(view, "no")
    assert html =~ "Proposed entries and adjustments: collected in your weekly digest"
  end

  test "values outside the options are rejected without minting atoms", %{conn: conn, cpa: cpa} do
    {:ok, view, _} = live(conn, ~p"/onboarding/#{cpa}")

    assert render_submit(view, "answer", %{"value" => ["web", "carrier_pigeon"]}) =~
             "Pick at least one."
  end
end
