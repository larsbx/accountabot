defmodule Accountabot.Engagement.Codec do
  @moduledoc """
  Engagement events ⇄ JSON-shaped records. Every atom is decoded against a
  closed vocabulary, so stored data can never mint atoms; an unknown value
  raises `ArgumentError`.
  """

  alias Accountabot.{Engagement.Item, Policy, Workflow}

  @tiers [:auto, :propose, :reserved]
  @statuses [:open, :applied, :approved, :rejected]
  @decisions [:approve, :reject]

  def encode({:opened, m}), do: rec("opened", m)
  def encode({:entered, stage}), do: rec("entered", %{stage: stage})
  def encode({:raised, %Item{} = i}), do: rec("raised", Map.from_struct(i))
  def encode({:applied, id}), do: rec("applied", %{id: id})

  def encode({:resolved, id, d, actor}),
    do: rec("resolved", %{id: id, decision: d, actor: actor(actor)})

  def encode({:closed}), do: rec("closed", %{})

  def decode(%{type: "opened", data: d}) do
    {:opened,
     %{
       id: d["id"],
       type: atom(d["type"], Workflow.types()),
       client: d["client"],
       policy: %{
         materiality: d["policy"]["materiality"],
         min_confidence: d["policy"]["min_confidence"]
       }
     }}
  end

  def decode(%{type: "entered", data: %{"stage" => s}}), do: {:entered, atom(s, stages())}

  def decode(%{type: "raised", data: d}) do
    {:raised,
     %Item{
       id: d["id"],
       kind: atom(d["kind"], Policy.kinds()),
       amount: d["amount"],
       confidence: d["confidence"],
       reversible?: d["reversible?"],
       tier: atom(d["tier"], @tiers),
       stage: atom(d["stage"], stages()),
       status: atom(d["status"], @statuses)
     }}
  end

  def decode(%{type: "applied", data: %{"id" => id}}), do: {:applied, id}

  def decode(%{type: "resolved", data: %{"id" => id, "decision" => d, "actor" => a}}),
    do: {:resolved, id, atom(d, @decisions), actor(a)}

  def decode(%{type: "closed"}), do: {:closed}
  def decode(%{type: t}), do: raise(ArgumentError, "unknown event type #{inspect(t)}")

  defp rec(type, data), do: %{type: type, data: data}

  defp actor(:agent), do: "agent"
  defp actor({:cpa, id}), do: %{"cpa" => id}
  defp actor("agent"), do: :agent
  defp actor(%{"cpa" => id}), do: {:cpa, id}

  defp stages, do: Workflow.types() |> Enum.flat_map(&Workflow.stages/1) |> Enum.uniq()

  defp atom(s, allowed),
    do:
      Enum.find(allowed, &(Atom.to_string(&1) == s)) ||
        raise(ArgumentError, "unknown value #{inspect(s)}")
end
