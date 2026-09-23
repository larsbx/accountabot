defmodule AccountabotWeb.Components do
  @moduledoc "Presentation components shared by the CPA surfaces."
  use Phoenix.Component

  @doc "Renders one evidence value: text, a list, a table of rows, or a placeholder."
  attr(:value, :any, required: true)

  def evidence(%{value: nil} = assigns), do: ~H|<p class="muted">Not available yet</p>|
  def evidence(%{value: v} = assigns) when is_binary(v), do: ~H|<p>{@value}</p>|

  def evidence(%{value: [%{} | _] = rows} = assigns) do
    assigns = assign(assigns, cols: rows |> Enum.flat_map(&Map.keys/1) |> Enum.uniq())

    ~H"""
    <table>
      <tr><th :for={c <- @cols}>{c}</th></tr>
      <tr :for={r <- @value}><td :for={c <- @cols}>{r[c]}</td></tr>
    </table>
    """
  end

  def evidence(%{value: v} = assigns) when is_list(v),
    do: ~H|<ul><li :for={x <- @value}>{x}</li></ul>|

  def evidence(assigns), do: ~H|<p>{inspect(@value)}</p>|
end
