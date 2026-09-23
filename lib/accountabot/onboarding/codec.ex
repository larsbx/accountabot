defmodule Accountabot.Onboarding.Codec do
  @moduledoc "Onboarding events ⇄ JSON records, decoded against the question definitions."

  alias Accountabot.Onboarding

  def encode({:answered, id, v}), do: %{type: "answered", data: %{question: id, value: v}}

  def decode(%{type: "answered", data: %{"question" => q, "value" => v}}) do
    question =
      Enum.find(Onboarding.questions(), &(Atom.to_string(&1.id) == q)) ||
        raise ArgumentError, "unknown question #{inspect(q)}"

    value = if is_list(v), do: Enum.map(v, &option(&1, question)), else: option(v, question)

    if Onboarding.valid?(question, value),
      do: {:answered, question.id, value},
      else: raise(ArgumentError, "invalid answer to #{q}")
  end

  defp option(s, q),
    do:
      Enum.find(q.options, &(Atom.to_string(&1) == s)) ||
        raise(ArgumentError, "unknown option #{inspect(s)}")
end
