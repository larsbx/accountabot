defmodule Accountabot.Policy do
  @moduledoc """
  Autonomy tiers. Default-deny: an action is `:auto` only if its kind is
  allowlisted AND it is below materiality, above the confidence floor, and
  reversible. Kinds that require the CPA's licence are always `:reserved`.

      classify(a) = :reserved  if a.kind ∈ R
                  = :auto      if a.kind ∈ A ∧ a.amount < m ∧ a.confidence ≥ c ∧ a.reversible?
                  = :propose   otherwise
  """

  @reserved [
    :accept_engagement,
    :engagement_letter,
    :sign_off,
    :file_return,
    :tax_position,
    :client_advice
  ]
  @auto [:categorize, :bank_match, :document_request, :accrual_flag]
  @proposal [:adjusting_entry, :reclassification, :journal_entry, :accrual, :write_off]

  @type tier :: :auto | :propose | :reserved

  def reserved_kinds, do: @reserved
  def auto_kinds, do: @auto

  @doc "The closed vocabulary of item kinds."
  def kinds, do: @reserved ++ @auto ++ @proposal

  def config(opts \\ []),
    do: Map.merge(%{materiality: 1_000_00, min_confidence: 0.95}, Map.new(opts))

  @spec classify(map, map) :: tier
  def classify(%{kind: k}, _) when k in @reserved, do: :reserved

  def classify(%{kind: k, amount: amt, confidence: c, reversible?: true}, %{
        materiality: m,
        min_confidence: min
      })
      when k in @auto and amt < m and c >= min,
      do: :auto

  def classify(_, _), do: :propose
end
