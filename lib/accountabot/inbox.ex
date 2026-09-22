defmodule Accountabot.Inbox do
  @moduledoc """
  Projection of what needs the CPA, per channel:

      reserved ∧ open → dashboard, sms     (act now)
      propose  ∧ open → dashboard, digest  (batchable)
      applied (auto)  → digest             (FYI; CPA may reverse)
  """

  @tier_rank %{reserved: 0, propose: 1, auto: 2}

  def channels(%{tier: :reserved, status: :open}), do: [:dashboard, :sms]
  def channels(%{tier: :propose, status: :open}), do: [:dashboard, :digest]
  def channels(%{status: :applied}), do: [:digest]
  def channels(_), do: []

  @doc "`{engagement_id, item}` pairs for `channel`, reserved first, then by amount desc."
  def queue(engagements, channel) do
    for(
      e <- engagements,
      i <- Enum.sort_by(Map.values(e.items), & &1.id),
      channel in channels(i),
      do: {e.id, i}
    )
    |> Enum.sort_by(fn {_, i} -> {@tier_rank[i.tier], -i.amount} end)
  end
end
