defmodule Accountabot.Gen do
  @moduledoc "Seeded generators for invariant checks (no external deps)."

  alias Accountabot.{Engagement, Workflow}

  @runs 500
  @cpa {:cpa, "cpa-1"}

  def check(gen, prop) do
    :rand.seed(:exsss, {1, 2, 3})
    Enum.each(1..@runs, fn _ -> gen.() |> prop.() end)
  end

  def int(lo, hi), do: lo + :rand.uniform(hi - lo + 1) - 1
  def float01, do: :rand.uniform()
  def bool, do: :rand.uniform(2) == 1
  def one_of(xs), do: Enum.random(xs)

  @doc "A random but valid engagement history: `{type, events}`."
  def engagement_log do
    type = one_of(Workflow.types())

    {:ok, s, log} =
      Engagement.handle(
        nil,
        {:open, %{id: "eng", type: type, client: "c", cpa_id: one_of([nil, "cpa-1"])}}
      )

    {_, log} =
      Enum.reduce(1..int(1, 40), {s, log}, fn i, {s, log} ->
        case Engagement.handle(s, random_cmd(s, i)) do
          {:ok, s, ev} -> {s, log ++ ev}
          {:error, _} -> {s, log}
        end
      end)

    {type, log}
  end

  defp random_cmd(s, i) do
    actor = one_of([:agent, @cpa])
    open = s.items |> Map.values() |> Enum.filter(&(&1.status == :open))

    case {one_of([:advance, :raise, :resolve]), open} do
      {:raise, _} ->
        {:raise,
         %{
           id: "r#{i}",
           kind: one_of([:categorize, :adjusting_entry, :sign_off]),
           amount: int(0, 2_000_00),
           confidence: float01(),
           reversible?: bool(),
           evidence:
             one_of([
               %{},
               %{summary: "s#{i}", ledger_impact: [%{"account" => "1000", "debit" => i}]}
             ])
         }}

      {:resolve, [_ | _]} ->
        {:resolve, one_of(open).id, one_of([:approve, :reject]), actor}

      _ ->
        {:advance, actor}
    end
  end
end
