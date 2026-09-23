defmodule Accountabot.Cpas do
  @moduledoc "CPA onboarding and profiles: `Accountabot.Aggregate` over stream `cpa-<id>`."

  alias Accountabot.{Aggregate, Onboarding, Profile}

  def answer(store, cpa_id, question, value),
    do: Aggregate.execute(store, spec(cpa_id), {:answer, question, value})

  def next_question(store, cpa_id), do: store |> answers(cpa_id) |> Onboarding.next()

  def profile(store, cpa_id), do: store |> answers(cpa_id) |> Profile.from_answers()

  defp answers(store, cpa_id), do: store |> Aggregate.load(spec(cpa_id)) |> elem(1)

  defp spec(id), do: %{decider: Onboarding, codec: Onboarding.Codec, stream: "cpa-#{id}"}
end
