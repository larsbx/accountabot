defmodule Accountabot.BooksTest do
  use ExUnit.Case, async: true
  @moduletag :postgres
  alias Accountabot.{Books, Ledger}

  @db Accountabot.TestDB
  @chart [{"1000", "Cash", :asset}, {"4000", "Revenue", :revenue}, {"6000", "Rent", :expense}]

  setup do
    book = "book-#{Base.encode16(:crypto.strong_rand_bytes(8))}"
    :ok = Books.open(@db, book, @chart)
    {:ok, book: book}
  end

  defp entry(id, lines), do: %{id: id, date: ~D[2026-09-01], memo: "m #{id}", lines: lines}

  test "posted entries load back into an identical ledger", %{book: b} do
    es = [
      entry("je1", [{"1000", :debit, 500_00}, {"4000", :credit, 500_00}]),
      entry("je2", [{"6000", :debit, 120_00}, {"1000", :credit, 100_00}, {"1000", :credit, 20_00}])
    ]

    Enum.each(es, &(:ok = Books.post(@db, b, &1)))
    expected = Enum.reduce(es, Ledger.new(@chart), &elem(Ledger.post(&2, &1), 1))

    assert Books.load(@db, b) == {:ok, expected}
  end

  test "domain validation runs before any write", %{book: b} do
    assert Books.post(@db, b, entry("x", [{"1000", :debit, 1}, {"4000", :credit, 2}])) ==
             {:error, :unbalanced}

    assert Books.post(@db, b, entry("x", [{"9999", :debit, 1}, {"4000", :credit, 1}])) ==
             {:error, {:unknown_account, "9999"}}

    assert {:ok, %Ledger{entries: []}} = Books.load(@db, b)
  end

  test "duplicate entry ids are rejected", %{book: b} do
    e = entry("je1", [{"6000", :debit, 1}, {"1000", :credit, 1}])
    :ok = Books.post(@db, b, e)
    assert Books.post(@db, b, e) == {:error, {:duplicate_entry, "je1"}}
  end

  test "books are isolated per client", %{book: b} do
    :ok = Books.post(@db, b, entry("je1", [{"6000", :debit, 1}, {"1000", :credit, 1}]))
    other = b <> "-other"
    :ok = Books.open(@db, other, @chart)
    assert :ok = Books.post(@db, other, entry("je1", [{"6000", :debit, 1}, {"1000", :credit, 1}]))
    assert Books.open(@db, b, @chart) == {:error, {:book_exists, b}}
  end

  test "the database itself refuses unbalanced entries (defence in depth)", %{book: b} do
    # The deferred trigger fires at COMMIT, which Postgrex surfaces as a raise.
    assert_raise Postgrex.Error, ~r/unbalanced journal entry/, fn ->
      Postgrex.transaction(@db, fn c ->
        Postgrex.query!(
          c,
          "INSERT INTO journal_entries (book_id, id, date, memo) VALUES ($1, 'raw', '2026-09-01', '')",
          [b]
        )

        Postgrex.query!(
          c,
          "INSERT INTO journal_lines (book_id, entry_id, line_no, account_code, side, amount) VALUES ($1, 'raw', 1, '1000', 'debit', 5), ($1, 'raw', 2, '4000', 'credit', 4)",
          [b]
        )
      end)
    end

    assert {:error, {:unknown_book, _}} = Accountabot.Books.load(@db, "no-such-book")
    assert {:ok, %Accountabot.Ledger{entries: []}} = Accountabot.Books.load(@db, b)
  end

  test "journal rows are append-only", %{book: b} do
    :ok = Books.post(@db, b, entry("je1", [{"6000", :debit, 1}, {"1000", :credit, 1}]))

    for sql <- [
          "UPDATE journal_lines SET amount = 2 WHERE book_id = $1",
          "DELETE FROM journal_entries WHERE book_id = $1"
        ] do
      assert {:error, %Postgrex.Error{postgres: %{message: "append-only table" <> _}}} =
               Postgrex.query(@db, sql, [b])
    end
  end
end
