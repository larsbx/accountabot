defmodule Accountabot.Onboarding.Codec do
  @moduledoc "Onboarding events ⇄ JSON records, decoded against the question definitions."

  alias Accountabot.Onboarding

  def encode({:answered, id, v}), do: %{type: "answered", data: %{question: id, value: v}}

  def decode(%{type: "answered", data: %{"question" => q, "value" => v}}) do
    question =
      Enum.find(Onboarding.questions(), &(Atom.to_string(&1.id) == q)) ||
        raise ArgumentError, "unknown question #{inspect(q)}"

    with {:ok, value} <- Onboarding.cast(question, v),
         true <- Onboarding.valid?(question, value) do
      {:answered, question.id, value}
    else
      _ -> raise ArgumentError, "invalid answer to #{q}: #{inspect(v)}"
    end
  end
end
