defmodule Accountabot.Demo do
  @moduledoc "Sample engagements for a CPA, so the review screen has something real to show in dev."

  alias Accountabot.{Engagements, Practice}

  @items [
    %{
      id: "je-rent-accrual",
      kind: :adjusting_entry,
      amount: 4_200_00,
      confidence: 0.91,
      reversible?: true,
      evidence: %{
        summary: "Accrue September rent — lease invoice not yet received",
        ledger_impact: [
          %{"account" => "6000 Rent", "debit" => "$4,200.00"},
          %{"account" => "2100 Accrued liabilities", "credit" => "$4,200.00"}
        ],
        agent_reasoning:
          "Lease (Drive: /Leases/2025-bakery.pdf) fixes rent at $4,200 due on the 1st. No bill in AP for September.",
        prior_period: "August: $4,200.00 posted 2026-08-02",
        source_documents: ["Leases/2025-bakery.pdf §3.1"]
      }
    },
    %{
      id: "reclass-equipment",
      kind: :reclassification,
      amount: 2_899_00,
      confidence: 0.83,
      reversible?: true,
      evidence: %{
        summary: "Reclassify stand mixer from Supplies to Equipment (capitalise)",
        ledger_impact: [
          %{"account" => "1500 Equipment", "debit" => "$2,899.00"},
          %{"account" => "6200 Supplies", "credit" => "$2,899.00"}
        ],
        agent_reasoning:
          "Above the $2,500 capitalisation threshold in the client's policy; useful life > 1 year.",
        source_documents: ["Receipts/2026-09-11 KitchenAid.pdf"]
      }
    },
    %{
      id: "cat-flour",
      kind: :categorize,
      amount: 312_40,
      confidence: 0.99,
      reversible?: true,
      evidence: %{
        summary: "Categorised Giusto's Flour → 5000 Cost of goods sold",
        agent_reasoning: "Same vendor categorised identically in 14 prior months."
      }
    }
  ]

  def seed(store, cpa_id) do
    open = fn id, type, client ->
      Engagements.execute(
        store,
        id,
        {:open, %{id: id, type: type, client: client, cpa_id: cpa_id}}
      )
    end

    {:ok, _, _} = open.("#{cpa_id}-close-2026-09", :monthly_close, "Mama Woodpecker Bakery")
    {:ok, _, _} = open.("#{cpa_id}-1120s-2025", :tax_return, "Kestrel Design LLC")
    Enum.each(@items, &({:ok, _, _} = Practice.raise_item(store, "#{cpa_id}-close-2026-09", &1)))
    :ok
  end
end
