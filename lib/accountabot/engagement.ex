defmodule Accountabot.Engagement do
  @moduledoc """
  An engagement as an event-sourced decider:

      decide : state × command → {:ok, [event]} | {:error, reason}
      evolve : state × event   → state
      state  = foldl(evolve, nil, events)

  Commands
    {:open, %{id, type, client}}
    {:raise, %{id, kind, amount, confidence, reversible?}}   — tier assigned by Policy
    {:resolve, item_id, :approve | :reject, actor}           — CPA only
    {:advance, actor}

  An engagement may leave a stage iff no item is open and every gate kind of
  the stage has an approved item raised in that stage.
  """

  alias Accountabot.{Policy, Workflow}

  defstruct [:id, :type, :client, :policy, :stage, status: :active, items: %{}]

  defmodule Item do
    @moduledoc false
    defstruct [:id, :kind, :amount, :confidence, :reversible?, :tier, :stage, status: :open]
  end

  @type actor :: :agent | {:cpa, term}

  def handle(state, cmd) do
    with {:ok, events} <- decide(state, cmd),
         do: {:ok, Enum.reduce(events, state, &evolve(&2, &1)), events}
  end

  def replay(events), do: Enum.reduce(events, nil, &evolve(&2, &1))

  # -- decide ---------------------------------------------------------------

  def decide(nil, {:open, %{id: id, type: type, client: _} = meta}) when is_binary(id) do
    meta =
      meta |> Map.take([:id, :type, :client, :policy]) |> Map.put_new(:policy, Policy.config())

    if type in Workflow.types(),
      do: {:ok, [{:opened, meta} | enter(type, :intake)]},
      else: {:error, {:unknown_workflow, type}}
  end

  def decide(nil, _), do: {:error, :not_open}
  def decide(%__MODULE__{}, {:open, _}), do: {:error, :already_open}
  def decide(%__MODULE__{status: :closed}, _), do: {:error, :closed}

  def decide(%__MODULE__{} = s, {:raise, %{id: id, kind: kind} = attrs}) when is_binary(id) do
    cond do
      Map.has_key?(s.items, id) ->
        {:error, {:duplicate_item, id}}

      kind not in Policy.kinds() ->
        {:error, {:unknown_kind, kind}}

      true ->
        item =
          struct!(
            Item,
            Map.merge(attrs, %{tier: Policy.classify(attrs, s.policy), stage: s.stage})
          )

        {:ok, [{:raised, item} | if(item.tier == :auto, do: [{:applied, id}], else: [])]}
    end
  end

  def decide(%__MODULE__{} = s, {:resolve, id, decision, actor})
      when decision in [:approve, :reject] do
    with {:ok, item} <- fetch_item(s, id),
         :ok <- authorize(actor),
         :ok <- resolvable(item.status, decision),
         do: {:ok, [{:resolved, id, decision, actor}]}
  end

  def decide(%__MODULE__{} = s, {:advance, _actor}) do
    case {blockers(s), Workflow.next(s.type, s.stage)} do
      {[], nil} -> {:ok, [{:closed}]}
      {[], next} -> {:ok, enter(s.type, next)}
      {b, _} -> {:error, {:blocked, b}}
    end
  end

  @doc "Open item ids, then unmet gates with no open item of that kind."
  def blockers(%__MODULE__{} = s) do
    here = s.items |> Map.values() |> Enum.filter(&(&1.stage == s.stage))
    open = s.items |> Map.values() |> Enum.filter(&(&1.status == :open))
    covered = MapSet.new(for i <- here, i.status in [:open, :approved], do: i.kind)

    Enum.sort(Enum.map(open, & &1.id)) ++
      for k <- Workflow.gates(s.type, s.stage), k not in covered, do: {:gate, k}
  end

  defp fetch_item(s, id),
    do: with(:error <- Map.fetch(s.items, id), do: {:error, {:unknown_item, id}})

  defp authorize({:cpa, _}), do: :ok
  defp authorize(_), do: {:error, :unauthorized}

  # Open items take either decision; an auto-applied item may only be reversed.
  defp resolvable(:open, _), do: :ok
  defp resolvable(:applied, :reject), do: :ok
  defp resolvable(_, _), do: {:error, :already_settled}

  defp enter(type, stage) do
    gate_items =
      for k <- Workflow.gates(type, stage),
          do:
            {:raised,
             %Item{
               id: "#{stage}:#{k}",
               kind: k,
               amount: 0,
               confidence: 1.0,
               reversible?: false,
               tier: :reserved,
               stage: stage
             }}

    [{:entered, stage} | gate_items]
  end

  # -- evolve ---------------------------------------------------------------

  def evolve(nil, {:opened, m}),
    do: %__MODULE__{id: m.id, type: m.type, client: m.client, policy: m.policy}

  def evolve(s, {:entered, stage}), do: %{s | stage: stage}
  def evolve(s, {:raised, item}), do: put_in(s.items[item.id], item)
  def evolve(s, {:applied, id}), do: put_in(s.items[id].status, :applied)
  def evolve(s, {:resolved, id, :approve, _}), do: put_in(s.items[id].status, :approved)
  def evolve(s, {:resolved, id, :reject, _}), do: put_in(s.items[id].status, :rejected)
  def evolve(s, {:closed}), do: %{s | status: :closed}
end
