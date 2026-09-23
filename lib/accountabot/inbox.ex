defmodule Accountabot.Inbox do
  @moduledoc """
  What needs the CPA, shaped by their `Accountabot.Profile`:

  - `queue/1`: every open item, reserved first, then by amount (what the review surface lists)
  - `alerts/2` and `digest/2`: items to push now, and items for the next digest
  - `card/2`: the view model for one item, with only the sections the CPA asked for
  """

  alias Accountabot.{Money, Profile}

  @tier_rank %{reserved: 0, propose: 1, auto: 2}

  def notification(%{status: :open, tier: t}, %Profile{notify: n})
      when t in [:reserved, :propose],
      do: n[t]

  def notification(%{status: :applied}, %Profile{notify: n}), do: n.auto
  def notification(_, _), do: :none

  def queue(engagements), do: select(engagements, &(&1.status == :open))
  def alerts(engagements, p), do: select(engagements, &match?({:now, _}, notification(&1, p)))
  def digest(engagements, p), do: select(engagements, &match?({:digest, _}, notification(&1, p)))

  @doc """
  `sections` is `[{section, content | nil}]` in the CPA's order; the summary falls back to kind and amount.
  A missing section is shown (as `nil`) only on items with a monetary effect, where a gap in the
  evidence is itself worth seeing; decisions with no amount show only what exists.
  """
  def card(item, %Profile{card_sections: sections}) do
    content = Map.put_new(item.evidence, :summary, default_summary(item))

    %{
      id: item.id,
      kind: item.kind,
      tier: item.tier,
      amount: item.amount,
      sections: for(s <- sections, item.amount > 0 or content[s] != nil, do: {s, content[s]})
    }
  end

  defp default_summary(%{kind: k, amount: a}) do
    title = k |> Profile.humanize() |> String.capitalize()
    if a > 0, do: "#{title} · #{Money.format(a)}", else: title
  end

  defp select(engagements, pred) do
    for(
      e <- engagements,
      i <- Enum.sort_by(Map.values(e.items), & &1.id),
      pred.(i),
      do: {e.id, i}
    )
    |> Enum.sort_by(fn {_, i} -> {@tier_rank[i.tier], -i.amount} end)
  end
end
