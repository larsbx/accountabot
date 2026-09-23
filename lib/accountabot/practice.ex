defmodule Accountabot.Practice do
  @moduledoc """
  Use cases that span a CPA's profile and their engagements. Every state change
  is broadcast on `"cpa:<id>"`, so open review screens update live.
  """

  alias Accountabot.{Cpas, Engagements}

  def topic(cpa_id), do: "cpa:#{cpa_id}"

  @doc "Opens an engagement for `cpa_id` under the autonomy policy their onboarding selected."
  def open_engagement(store, cpa_id, %{id: id} = attrs) do
    with {:ok, profile} <- Cpas.profile(store, cpa_id),
         do:
           execute(
             store,
             id,
             {:open, Map.merge(attrs, %{cpa_id: cpa_id, policy: profile.policy})}
           )
  end

  @doc "The agent raises an item on an engagement."
  def raise_item(store, engagement_id, attrs), do: execute(store, engagement_id, {:raise, attrs})

  @doc "The CPA resolves an item. Only the CPA supervising the engagement may resolve its items."
  def resolve(store, cpa_id, engagement_id, item_id, decision) do
    case Engagements.load(store, engagement_id) do
      {:ok, %{cpa_id: ^cpa_id}} ->
        execute(store, engagement_id, {:resolve, item_id, decision, {:cpa, cpa_id}})

      _ ->
        {:error, :not_found}
    end
  end

  defp execute(store, id, cmd) do
    with {:ok, state, events} <- Engagements.execute(store, id, cmd) do
      if state.cpa_id,
        do: Phoenix.PubSub.broadcast(Accountabot.PubSub, topic(state.cpa_id), {:engagement, id})

      {:ok, state, events}
    end
  end
end
