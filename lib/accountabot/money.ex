defmodule Accountabot.Money do
  @moduledoc "Formatting for integer minor units (USD cents)."

  @doc ~S'iex> Accountabot.Money.format(123_456_78)
"$123,456.78"'
  def format(cents) when is_integer(cents) do
    sign = if cents < 0, do: "-", else: ""
    {d, c} = {div(abs(cents), 100), rem(abs(cents), 100)}

    dollars =
      d
      |> Integer.to_string()
      |> String.reverse()
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.join(",")
      |> String.reverse()

    "#{sign}$#{dollars}.#{String.pad_leading(Integer.to_string(c), 2, "0")}"
  end
end
