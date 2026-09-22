defmodule Accountabot.EventStore do
  @moduledoc """
  Append-only streams with optimistic concurrency.

  A store is `{adapter, server}`. Records are `%{type: String.t(), data: map}`,
  with `data` JSON-shaped (string keys) on read, whichever adapter is used.

      append(s, v, rs) succeeds ⇔ version(s) = v, and then version(s) := v + |rs|
  """

  @type store :: {module, GenServer.server()}
  @type record :: %{type: String.t(), data: map}

  @callback read(GenServer.server(), String.t()) :: {:ok, [record], non_neg_integer}
  @callback append(GenServer.server(), String.t(), non_neg_integer, [record]) ::
              {:ok, pos_integer} | {:error, :wrong_expected_version}

  def read({mod, srv}, stream), do: mod.read(srv, stream)

  def append({mod, srv}, stream, expected, [_ | _] = records)
      when is_integer(expected) and expected >= 0,
      do: mod.append(srv, stream, expected, records)
end
