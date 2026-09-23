defmodule Accountabot.Onboarding do
  @moduledoc """
  CPA onboarding as data. Each question may carry `ask_if` conditions over
  earlier answers; `next/1` returns the first applicable, unanswered question.
  State is the answer map; answers may be revised at any time, and the
  derived `Accountabot.Profile` adapts.
  """

  use Accountabot.Decider

  @questions [
    %{
      id: :surfaces,
      type: :multi,
      options: [:web, :mobile, :email, :sms],
      prompt: "Where do you want to review the agent's work?"
    },
    %{
      id: :evidence,
      type: :multi,
      options: [:summary, :source_documents, :ledger_impact, :agent_reasoning, :prior_period],
      prompt: "What do you need to see to approve an item?"
    },
    %{
      id: :cadence,
      type: :single,
      options: [:realtime, :daily, :weekly],
      prompt: "How often do you want to review items that need your approval?"
    },
    %{
      id: :interrupt,
      type: :single,
      options: [:yes, :no],
      ask_if: [
        {:cadence, :not_in, [:realtime]},
        {:surfaces, :intersects, [:mobile, :sms, :email]}
      ],
      prompt: "Should items only you can decide (sign-offs, filings) interrupt you right away?"
    },
    %{
      id: :autonomy,
      type: :single,
      options: [:cautious, :balanced, :hands_off],
      prompt: "How much should the agent do without asking?"
    }
  ]

  def questions, do: @questions
  def question(id), do: Enum.find(@questions, &(&1.id == id))

  @spec next(map) :: map | :done
  def next(answers),
    do:
      Enum.find(
        @questions,
        :done,
        &(applicable?(&1, answers) and not Map.has_key?(answers, &1.id))
      )

  @doc "Answers that currently count: answered and applicable."
  def effective(answers),
    do: Map.filter(answers, fn {id, _} -> applicable?(question(id), answers) end)

  def applicable?(q, answers), do: Enum.all?(Map.get(q, :ask_if, []), &holds?(&1, answers))

  defp holds?({id, :not_in, xs}, a), do: Map.has_key?(a, id) and a[id] not in xs
  defp holds?({id, :intersects, xs}, a), do: Enum.any?(List.wrap(a[id]), &(&1 in xs))

  @doc "Whether `value` is a well-formed answer to `q`."
  def valid?(%{type: :single, options: o}, v), do: v in o

  def valid?(%{type: :multi, options: o}, [_ | _] = vs),
    do: vs == Enum.uniq(vs) and Enum.all?(vs, &(&1 in o))

  def valid?(_, _), do: false

  @impl true
  def initial, do: %{}

  @impl true
  def decide(answers, {:answer, id, value}) do
    case question(id) do
      nil ->
        {:error, {:unknown_question, id}}

      q ->
        if(not valid?(q, value),
          do: {:error, {:invalid_answer, id}},
          else: applicable(q, answers, value)
        )
    end
  end

  defp applicable(q, answers, value) do
    if applicable?(q, answers),
      do: {:ok, [{:answered, q.id, value}]},
      else: {:error, {:not_applicable, q.id}}
  end

  @impl true
  def evolve(answers, {:answered, id, value}), do: Map.put(answers, id, value)
end
