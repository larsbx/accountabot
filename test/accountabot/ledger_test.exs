defmodule Accountabot.LedgerTest do
  use ExUnit.Case, async: true
  import Accountabot.Gen
  alias Accountabot.Ledger

  @coa [
    {"1000", "Cash", :asset},
    {"2000", "Accounts payable", :liability},
    {"3000", "Owner equity", :equity},
    {"4000", "Revenue", :revenue},
    {"6000", "Rent", :expense}
  ]

  defp ledger, do: Ledger.new(@coa)

  test "posts a balanced entry and reports normal-side balances" do
    {:ok, l} =
      Ledger.post(ledger(), %{
        id: "je1",
        date: ~D[2026-09-01],
        memo: "Sale",
        lines: [{"1000", :debit, 500_00}, {"4000", :credit, 500_00}]
      })

    assert Ledger.balance(l, "1000") == 500_00
    assert Ledger.balance(l, "4000") == 500_00
    assert Ledger.balance(l, "6000") == 0
  end

  test "rejects invalid entries" do
    base = %{id: "x", date: ~D[2026-09-01], memo: ""}
    post = &Ledger.post(ledger(), Map.put(base, :lines, &1))

    assert post.([{"1000", :debit, 1}, {"4000", :credit, 2}]) == {:error, :unbalanced}
    assert post.([{"1000", :debit, 0}, {"4000", :credit, 0}]) == {:error, :non_positive_amount}
    assert post.([{"1000", :debit, 1}]) == {:error, :too_few_lines}

    assert post.([{"9999", :debit, 1}, {"4000", :credit, 1}]) ==
             {:error, {:unknown_account, "9999"}}
  end

  test "rejects duplicate entry ids (idempotent ingestion)" do
    e = %{
      id: "je1",
      date: ~D[2026-09-01],
      memo: "",
      lines: [{"6000", :debit, 1}, {"1000", :credit, 1}]
    }

    {:ok, l} = Ledger.post(ledger(), e)
    assert Ledger.post(l, e) == {:error, {:duplicate_entry, "je1"}}
  end

  test "∀ postings: Σ signed trial balance = 0 and A = L + E + (R − X)" do
    codes = Enum.map(@coa, &elem(&1, 0))

    gen = fn ->
      Enum.map(1..int(1, 20), fn i ->
        {dr, cr, amt} = {one_of(codes), one_of(codes), int(1, 1_000_000)}

        %{
          id: "e#{i}",
          date: ~D[2026-09-01],
          memo: "",
          lines: [{dr, :debit, amt}, {cr, :credit, amt}]
        }
      end)
    end

    check(gen, fn entries ->
      l = Enum.reduce(entries, ledger(), fn e, acc -> elem(Ledger.post(acc, e), 1) end)
      tb = Ledger.trial_balance(l)
      assert tb |> Map.values() |> Enum.sum() == 0

      by = fn type ->
        @coa
        |> Enum.filter(&(elem(&1, 2) == type))
        |> Enum.map(&Ledger.balance(l, elem(&1, 0)))
        |> Enum.sum()
      end

      assert by.(:asset) == by.(:liability) + by.(:equity) + by.(:revenue) - by.(:expense)
    end)
  end
end
