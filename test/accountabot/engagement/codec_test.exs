defmodule Accountabot.Engagement.CodecTest do
  use ExUnit.Case, async: true
  import Accountabot.Gen
  alias Accountabot.Engagement
  alias Accountabot.Engagement.Codec

  defp json_roundtrip(%{type: t, data: d}),
    do: %{type: t, data: d |> Jason.encode!() |> Jason.decode!()}

  test "∀ histories: decode ∘ json ∘ encode = id, so replay survives storage" do
    check(&engagement_log/0, fn {_, log} ->
      stored = Enum.map(log, &(&1 |> Codec.encode() |> json_roundtrip() |> Codec.decode()))
      assert stored == log
      assert Engagement.replay(stored) == Engagement.replay(log)
    end)
  end

  test "decoding never mints atoms from stored strings" do
    bad = %{
      type: "entered",
      data: %{"stage" => "definitely_not_a_stage_#{System.unique_integer()}"}
    }

    assert_raise ArgumentError, fn -> Codec.decode(bad) end
  end
end
