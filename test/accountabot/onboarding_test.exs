defmodule Accountabot.OnboardingTest do
  use ExUnit.Case, async: true
  import Accountabot.Gen
  alias Accountabot.Onboarding

  defp answer_all(answers, pick) do
    case Onboarding.next(answers) do
      :done ->
        answers

      q ->
        {:ok, answers, _} = Onboarding.handle(answers, {:answer, q.id, pick.(q)})
        answer_all(answers, pick)
    end
  end

  test "asks questions in order until done" do
    assert %{id: :surfaces} = Onboarding.next(%{})
    first = fn q -> if q.type == :multi, do: [hd(q.options)], else: hd(q.options) end
    assert Onboarding.next(answer_all(%{}, first)) == :done
  end

  test "conditional questions are skipped when they do not apply" do
    a = %{surfaces: [:web, :sms], evidence: [:summary], cadence: :realtime}
    assert %{id: :autonomy} = Onboarding.next(a)
    assert %{id: :interrupt} = Onboarding.next(%{a | cadence: :weekly})
    assert %{id: :autonomy} = Onboarding.next(%{a | cadence: :weekly, surfaces: [:web]})
  end

  test "answers are validated against the question" do
    s = %{}
    assert Onboarding.decide(s, {:answer, :nope, :x}) == {:error, {:unknown_question, :nope}}

    assert Onboarding.decide(s, {:answer, :cadence, :hourly}) ==
             {:error, {:invalid_answer, :cadence}}

    assert Onboarding.decide(s, {:answer, :surfaces, []}) ==
             {:error, {:invalid_answer, :surfaces}}

    assert Onboarding.decide(s, {:answer, :surfaces, :web}) ==
             {:error, {:invalid_answer, :surfaces}}

    assert Onboarding.decide(%{cadence: :realtime}, {:answer, :interrupt, :yes}) ==
             {:error, {:not_applicable, :interrupt}}
  end

  test "answers can be revised later" do
    {:ok, a, _} = Onboarding.handle(%{}, {:answer, :cadence, :weekly})
    {:ok, a, _} = Onboarding.handle(a, {:answer, :cadence, :daily})
    assert a.cadence == :daily
  end

  test "∀ random answer sessions: onboarding terminates within |questions| answers" do
    pick = fn q ->
      if q.type == :multi,
        do: Enum.take_random(q.options, int(1, length(q.options))),
        else: one_of(q.options)
    end

    check(fn -> pick end, fn pick ->
      {n, a} = count_answers(%{}, pick, 0)
      assert n <= length(Onboarding.questions())
      assert Onboarding.next(a) == :done
    end)
  end

  defp count_answers(a, pick, n) do
    case Onboarding.next(a) do
      :done -> {n, a}
      q -> count_answers(elem(Onboarding.handle(a, {:answer, q.id, pick.(q)}), 1), pick, n + 1)
    end
  end
end

defmodule Accountabot.Onboarding.CodecTest do
  use ExUnit.Case, async: true
  import Accountabot.Gen
  alias Accountabot.Onboarding
  alias Accountabot.Onboarding.Codec

  test "∀ valid answers: decode ∘ json ∘ encode = id" do
    gen = fn ->
      q = one_of(Onboarding.questions())

      v =
        if q.type == :multi,
          do: Enum.take_random(q.options, int(1, length(q.options))),
          else: one_of(q.options)

      {:answered, q.id, v}
    end

    check(gen, fn e ->
      %{type: t, data: d} = Codec.encode(e)
      assert Codec.decode(%{type: t, data: d |> Jason.encode!() |> Jason.decode!()}) == e
    end)
  end

  test "stored garbage raises instead of minting atoms" do
    assert_raise ArgumentError, fn ->
      Codec.decode(%{type: "answered", data: %{"question" => "cadence", "value" => "hourly"}})
    end
  end
end
