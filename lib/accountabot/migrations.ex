defmodule Accountabot.Migrations do
  @moduledoc """
  Schema as ordered, immutable data: `{version, name, [statement]}`.
  Never edit a released migration; append a new one.
  """

  @append_only """
  CREATE FUNCTION forbid_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
  BEGIN
    RAISE EXCEPTION 'append-only table: % on % is forbidden', TG_OP, TG_TABLE_NAME;
  END $$
  """

  defp guard(table),
    do: [
      "CREATE TRIGGER #{table}_no_mutation BEFORE UPDATE OR DELETE ON #{table} FOR EACH ROW EXECUTE FUNCTION forbid_mutation()",
      "CREATE TRIGGER #{table}_no_truncate BEFORE TRUNCATE ON #{table} FOR EACH STATEMENT EXECUTE FUNCTION forbid_mutation()"
    ]

  def all do
    [
      {1, "event_store",
       [
         @append_only,
         """
         CREATE TABLE events (
           position    bigserial   PRIMARY KEY,
           stream_id   text        NOT NULL,
           version     integer     NOT NULL CHECK (version > 0),
           type        text        NOT NULL,
           data        jsonb       NOT NULL,
           recorded_at timestamptz NOT NULL DEFAULT now(),
           UNIQUE (stream_id, version)
         )
         """
         | guard("events")
       ]},
      {2, "ledger",
       [
         """
         CREATE TABLE ledger_accounts (
           book_id text NOT NULL,
           code    text NOT NULL,
           name    text NOT NULL,
           type    text NOT NULL CHECK (type IN ('asset', 'liability', 'equity', 'revenue', 'expense')),
           PRIMARY KEY (book_id, code)
         )
         """,
         """
         CREATE TABLE journal_entries (
           book_id     text        NOT NULL,
           id          text        NOT NULL,
           date        date        NOT NULL,
           memo        text        NOT NULL DEFAULT '',
           position    bigserial   UNIQUE,
           recorded_at timestamptz NOT NULL DEFAULT now(),
           PRIMARY KEY (book_id, id)
         )
         """,
         """
         CREATE TABLE journal_lines (
           book_id      text    NOT NULL,
           entry_id     text    NOT NULL,
           line_no      integer NOT NULL CHECK (line_no > 0),
           account_code text    NOT NULL,
           side         text    NOT NULL CHECK (side IN ('debit', 'credit')),
           amount       bigint  NOT NULL CHECK (amount > 0),
           PRIMARY KEY (book_id, entry_id, line_no),
           FOREIGN KEY (book_id, entry_id) REFERENCES journal_entries,
           FOREIGN KEY (book_id, account_code) REFERENCES ledger_accounts
         )
         """,
         """
         CREATE FUNCTION journal_entry_balanced() RETURNS trigger LANGUAGE plpgsql AS $$
         DECLARE
           eid text := to_jsonb(NEW) ->> TG_ARGV[0]; -- entry-id column of the firing table
           n integer;
           net bigint;
         BEGIN
           SELECT count(*), coalesce(sum(CASE side WHEN 'debit' THEN amount ELSE -amount END), 0)
             INTO n, net FROM journal_lines WHERE book_id = NEW.book_id AND entry_id = eid;
           IF n < 2 OR net <> 0 THEN
             RAISE EXCEPTION 'unbalanced journal entry %/% (lines=%, net=%)', NEW.book_id, eid, n, net;
           END IF;
           RETURN NULL;
         END $$
         """,
         "CREATE CONSTRAINT TRIGGER journal_entries_balanced AFTER INSERT ON journal_entries DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION journal_entry_balanced('id')",
         "CREATE CONSTRAINT TRIGGER journal_lines_balanced AFTER INSERT ON journal_lines DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION journal_entry_balanced('entry_id')"
         | guard("journal_entries") ++ guard("journal_lines")
       ]}
    ]
  end
end
