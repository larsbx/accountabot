defmodule Accountabot.Decider do
  @moduledoc """
  The decider pattern: `decide : state × cmd → events`, `evolve : state × event → state`.
  `use Accountabot.Decider` derives `handle/2` and `replay/1` from those.
  """

  @callback initial() :: term
  @callback decide(state :: term, cmd :: term) :: {:ok, [term]} | {:error, term}
  @callback evolve(state :: term, event :: term) :: term

  defmacro __using__(_) do
    quote do
      @behaviour Accountabot.Decider
      def handle(state, cmd), do: Accountabot.Decider.handle(__MODULE__, state, cmd)
      def replay(events), do: Accountabot.Decider.replay(__MODULE__, events)
    end
  end

  def handle(mod, state, cmd) do
    with {:ok, events} <- mod.decide(state, cmd),
         do: {:ok, Enum.reduce(events, state, &mod.evolve(&2, &1)), events}
  end

  def replay(mod, events), do: Enum.reduce(events, mod.initial(), &mod.evolve(&2, &1))
end
