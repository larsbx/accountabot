defmodule Accountabot.Ledger do
  @moduledoc """
  Immutable double-entry ledger. Amounts are integer minor units (cents).

  Internally balances are signed debit-positive, so the trial balance sums to 0
  by construction; `balance/2` reports them on the account's normal side.
  """

  @types [:asset, :liability, :equity, :revenue, :expense]
  @debit_normal [:asset, :expense]

  defstruct accounts: %{}, balances: %{}, entries: [], ids: MapSet.new()

  @type code :: String.t()
  @type line :: {code, :debit | :credit, pos_integer}
  @type entry :: %{id: term, date: Date.t(), memo: String.t(), lines: [line]}

  def new(chart) do
    accounts =
      Map.new(chart, fn {code, name, type} when type in @types -> {code, {name, type}} end)

    %__MODULE__{accounts: accounts, balances: Map.new(accounts, fn {c, _} -> {c, 0} end)}
  end

  @spec post(t, entry) :: {:ok, t} | {:error, term} when t: %__MODULE__{}
  def post(%__MODULE__{} = l, entry) do
    with :ok <- validate(l, entry) do
      balances =
        Enum.reduce(entry.lines, l.balances, fn {code, side, amt}, b ->
          Map.update!(b, code, &(&1 + signed(side, amt)))
        end)

      {:ok,
       %{l | balances: balances, entries: [entry | l.entries], ids: MapSet.put(l.ids, entry.id)}}
    end
  end

  def balance(%__MODULE__{} = l, code) do
    {_, type} = Map.fetch!(l.accounts, code)
    if type in @debit_normal, do: l.balances[code], else: -l.balances[code]
  end

  @doc "Signed (debit-positive) balances per account; values sum to 0."
  def trial_balance(%__MODULE__{balances: b}), do: b

  def entries(%__MODULE__{entries: e}), do: Enum.reverse(e)

  defp signed(:debit, amt), do: amt
  defp signed(:credit, amt), do: -amt

  defp validate(l, %{id: id, lines: lines}) do
    cond do
      MapSet.member?(l.ids, id) ->
        {:error, {:duplicate_entry, id}}

      length(lines) < 2 ->
        {:error, :too_few_lines}

      unknown = Enum.find(lines, &(not Map.has_key?(l.accounts, elem(&1, 0)))) ->
        {:error, {:unknown_account, elem(unknown, 0)}}

      Enum.any?(lines, fn {_, _, amt} -> not (is_integer(amt) and amt > 0) end) ->
        {:error, :non_positive_amount}

      Enum.sum(Enum.map(lines, fn {_, s, a} -> signed(s, a) end)) != 0 ->
        {:error, :unbalanced}

      true ->
        :ok
    end
  end
end
