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

  alias Accountabot.{Onboarding, Policy}

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
end
