defmodule Accountabot.PracticeTest do
  use ExUnit.Case, async: true
  alias Accountabot.{Cpas, EventStore, Practice, Profile}

  setup do
    {:ok, store: {EventStore.Memory, start_supervised!(EventStore.Memory)}}
  end

  test "engagements open under the CPA's autonomy policy", %{store: st} do
    assert Practice.open_engagement(st, "cpa-1", %{id: "e1", type: :monthly_close, client: "c"}) ==
             {:error, {:incomplete, :surfaces}}

    for {q, v} <- [surfaces: [:web], evidence: [:summary], cadence: :weekly, autonomy: :cautious],
        do: {:ok, _, _} = Cpas.answer(st, "cpa-1", q, v)

    {:ok, e, _} =
      Practice.open_engagement(st, "cpa-1", %{id: "e1", type: :monthly_close, client: "c"})

    assert e.policy == Profile.policy_for(:cautious)
    assert e.cpa_id == "cpa-1"
  end
end
