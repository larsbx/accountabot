defmodule Accountabot.Profile do
  @moduledoc """
  What the agent and UI derive from a CPA's onboarding answers.

      notify[tier] ∈ {{:now, surface}, {:digest, surface}}
        reserved: :now  if cadence = realtime ∨ interrupt = yes
        propose:  :now  if cadence = realtime
        auto:     :digest (FYI; the CPA can reverse)
        :now    goes via the most direct chosen surface (mobile > sms > email), else the primary one
        :digest goes via email if chosen, else the primary surface (web > mobile > email > sms)

      card_sections = [:summary | evidence]      policy = policy_for(autonomy)
  """

  alias Accountabot.{Money, Onboarding, Policy}

  defstruct [:surfaces, :cadence, :digest, :autonomy, :notify, :card_sections, :policy]

  @primary_order [:web, :mobile, :email, :sms]
  @interrupt_order [:mobile, :sms, :email]

  @policies %{
    cautious: [materiality: 250_00, min_confidence: 0.99],
    balanced: [],
    hands_off: [materiality: 5_000_00, min_confidence: 0.9]
  }

  def policy_for(level), do: Policy.config(Map.fetch!(@policies, level))

  def from_answers(answers) do
    case Onboarding.next(answers) do
      :done -> {:ok, derive(Onboarding.effective(answers))}
      q -> {:error, {:incomplete, q.id}}
    end
  end

  defp derive(a) do
    first = fn order -> Enum.find(order, &(&1 in a.surfaces)) end
    primary = first.(@primary_order)
    now = {:now, first.(@interrupt_order) || primary}
    digest = {:digest, if(:email in a.surfaces, do: :email, else: primary)}
    realtime? = a.cadence == :realtime

    %__MODULE__{
      surfaces: a.surfaces,
      cadence: a.cadence,
      digest: if(realtime?, do: :daily, else: a.cadence),
      autonomy: a.autonomy,
      notify: %{
        reserved: if(realtime? or a[:interrupt] == :yes, do: now, else: digest),
        propose: if(realtime?, do: now, else: digest),
        auto: digest
      },
      card_sections: Enum.uniq([:summary | a.evidence]),
      policy: policy_for(a.autonomy)
    }
  end

  @doc "The derived behaviour in plain language, for the end of onboarding and the settings screen."
  def describe(%__MODULE__{notify: n, policy: pol, card_sections: cs, digest: d}) do
    [
      "Sign-offs, filings and other decisions only you can make: #{route(n.reserved, "collected in", d)}.",
      "Proposed entries and adjustments: #{route(n.propose, "collected in", d)}.",
      "Routine work I do on my own: #{route(n.auto, "listed in", d)}, where you can reverse it.",
      "I act alone only below #{Money.format(pol.materiality)} and at ≥ #{round(pol.min_confidence * 100)}% confidence; everything else waits for you.",
      "Each item shows: #{Enum.map_join(cs, ", ", &humanize/1)}."
    ]
  end

  def humanize(atom), do: atom |> Atom.to_string() |> String.replace("_", " ")

  defp route({:now, via}, _, _), do: "sent to you right away #{via(via)}"
  defp route({:digest, via}, verb, d), do: "#{verb} your #{d} digest #{via(via)}"

  defp via(:web), do: "on the web"
  defp via(:mobile), do: "on your phone"
  defp via(:email), do: "by email"
  defp via(:sms), do: "by SMS"
end
