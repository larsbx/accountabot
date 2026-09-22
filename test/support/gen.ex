defmodule Accountabot.Gen do
  @moduledoc "Seeded generators for invariant checks (no external deps)."

  @runs 500

  def check(gen, prop) do
    :rand.seed(:exsss, {1, 2, 3})
    Enum.each(1..@runs, fn _ -> gen.() |> prop.() end)
  end

  def int(lo, hi), do: lo + :rand.uniform(hi - lo + 1) - 1
  def float01, do: :rand.uniform()
  def bool, do: :rand.uniform(2) == 1
  def one_of(xs), do: Enum.random(xs)
end
