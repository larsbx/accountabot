defmodule Accountabot.Books do
  @moduledoc """
  Per-client ledgers ("books") in Postgres.

  `Ledger.validate/2` runs first, so domain errors come back as values and
  nothing is written. The schema then enforces the same invariants on its own
  (balanced entries through a deferred constraint trigger, append-only rows),
  so a bug here or a raw SQL write still can't corrupt the books.
  """

  alias Accountabot.Ledger

  def open(conn, book_id, chart) do
    Postgrex.transaction(conn, fn c ->
      Enum.each(chart, fn {code, name, type} ->
        case Postgrex.query(
               c,
               "INSERT INTO ledger_accounts (book_id, code, name, type) VALUES ($1, $2, $3, $4)",
               [
                 book_id,
                 code,
                 name,
                 Atom.to_string(type)
               ]
             ) do
          {:ok, _} ->
            :ok

          {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} ->
            Postgrex.rollback(c, {:book_exists, book_id})

          {:error, e} ->
            raise e
        end
      end)
    end)
    |> ok()
  end

  def post(conn, book_id, entry) do
    with {:ok, chart} <- chart(conn, book_id),
         :ok <- Ledger.validate(Ledger.new(chart), entry) do
      Postgrex.transaction(conn, fn c ->
        case Postgrex.query(
               c,
               "INSERT INTO journal_entries (book_id, id, date, memo) VALUES ($1, $2, $3, $4)",
               [
                 book_id,
                 entry.id,
                 entry.date,
                 entry.memo
               ]
             ) do
          {:ok, _} ->
            insert_lines(c, book_id, entry)

          {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} ->
            Postgrex.rollback(c, {:duplicate_entry, entry.id})

          {:error, e} ->
            raise e
        end
      end)
      |> ok()
    end
  end

  def load(conn, book_id) do
    with {:ok, chart} <- chart(conn, book_id) do
      %{rows: rows} =
        Postgrex.query!(
          conn,
          """
          SELECT e.id, e.date, e.memo, l.account_code, l.side, l.amount
          FROM journal_entries e JOIN journal_lines l ON l.book_id = e.book_id AND l.entry_id = e.id
          WHERE e.book_id = $1 ORDER BY e.position, l.line_no
          """,
          [book_id]
        )

      rows
      |> Enum.chunk_by(&hd/1)
      |> Enum.map(fn [[id, date, memo | _] | _] = ls ->
        %{
          id: id,
          date: date,
          memo: memo,
          lines: for([_, _, _, a, s, amt] <- ls, do: {a, side(s), amt})
        }
      end)
      |> Enum.reduce_while({:ok, Ledger.new(chart)}, fn e, {:ok, l} ->
        case Ledger.post(l, e) do
          {:ok, l} -> {:cont, {:ok, l}}
          error -> {:halt, error}
        end
      end)
    end
  end

  defp chart(conn, book_id) do
    case Postgrex.query!(
           conn,
           "SELECT code, name, type FROM ledger_accounts WHERE book_id = $1",
           [book_id]
         ).rows do
      [] -> {:error, {:unknown_book, book_id}}
      rows -> {:ok, for([c, n, t] <- rows, do: {c, n, String.to_existing_atom(t)})}
    end
  end

  defp insert_lines(c, book_id, %{id: id, lines: lines}) do
    {codes, sides, amounts} =
      lines |> Enum.map(fn {a, s, amt} -> {a, Atom.to_string(s), amt} end) |> unzip3()

    Postgrex.query!(
      c,
      """
      INSERT INTO journal_lines (book_id, entry_id, line_no, account_code, side, amount)
      SELECT $1, $2, n, a, s, amt FROM unnest($3::text[], $4::text[], $5::bigint[]) WITH ORDINALITY AS x(a, s, amt, n)
      """,
      [book_id, id, codes, sides, amounts]
    )
  end

  defp unzip3(triples),
    do:
      {Enum.map(triples, &elem(&1, 0)), Enum.map(triples, &elem(&1, 1)),
       Enum.map(triples, &elem(&1, 2))}

  defp side("debit"), do: :debit
  defp side("credit"), do: :credit

  defp ok({:ok, _}), do: :ok
  defp ok(error), do: error
end
