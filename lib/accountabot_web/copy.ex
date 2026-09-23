defmodule AccountabotWeb.Copy do
  @moduledoc "Human wording for onboarding options. Presentation only; the domain keeps atoms."

  @options %{
    surfaces: %{
      web: {"Web app", "A full review screen on your computer"},
      mobile: {"Phone", "Push notifications and quick approvals"},
      email: {"Email", "Summaries and links in your inbox"},
      sms: {"Text message", "Short alerts for anything urgent"}
    },
    evidence: %{
      summary: {"One-line summary", "What the item is, in plain words"},
      source_documents: {"Source documents", "The receipts, statements or contracts behind it"},
      ledger_impact: {"Ledger impact", "The exact debits and credits"},
      agent_reasoning: {"My reasoning", "Why I think this is right"},
      prior_period: {"Prior period", "How the same thing was handled last time"}
    },
    cadence: %{
      realtime: {"As things come up", "I'll bring items to you the moment they're ready"},
      daily: {"Once a day", "One daily review"},
      weekly: {"Once a week", "One weekly review"}
    },
    interrupt: %{
      yes: {"Yes, interrupt me", "Sign-offs and filings reach you right away"},
      no: {"No, keep them for my review", "They wait with everything else"}
    },
    autonomy: %{
      cautious: {"Cautious", "Act alone only on small, near-certain items (< $250, ≥ 99%)"},
      balanced: {"Balanced", "Routine items under $1,000 at ≥ 95% confidence"},
      hands_off: {"Hands-off", "Routine items under $5,000 at ≥ 90% confidence"}
    }
  }

  def option(question_id, option), do: @options[question_id][option]
  def label(question_id, option), do: elem(option(question_id, option), 0)

  def answer(question_id, values),
    do: values |> List.wrap() |> Enum.map_join(", ", &label(question_id, &1))
end
