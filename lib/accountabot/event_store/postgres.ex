defmodule Accountabot.EventStore.Postgres do
  @moduledoc """
  Postgres adapter over the `events` table. Concurrency is enforced by
  `UNIQUE (stream_id, version)`: a racing writer hits a unique violation and
  gets `:wrong_expected_version`, never a gap or a fork.
  """

  @behaviour Accountabot.EventStore

  @impl true
  def streams(conn, prefix) do
    %{rows: rows} =
      Postgrex.query!(
        conn,
        "SELECT DISTINCT stream_id FROM events WHERE starts_with(stream_id, $1)",
        [prefix]
      )

    List.flatten(rows)
  end

  @impl true
  def read(conn, stream) do
    %{rows: rows} =
      Postgrex.query!(
        conn,
        "SELECT type, data, version FROM events WHERE stream_id = $1 ORDER BY version",
        [stream]
      )

    {:ok, Enum.map(rows, fn [t, d, _] -> %{type: t, data: d} end),
     rows |> List.last([nil, nil, 0]) |> List.last()}
  end

  @impl true
  def append(conn, stream, expected, records) do
    versions = Enum.to_list((expected + 1)..(expected + length(records)))

    Postgrex.transaction(conn, fn c ->
      with {:ok, %{rows: [[^expected]]}} <-
             Postgrex.query(
               c,
               "SELECT coalesce(max(version), 0)::int FROM events WHERE stream_id = $1",
               [stream]
             ),
           {:ok, _} <-
             Postgrex.query(
               c,
               """
               INSERT INTO events (stream_id, version, type, data)
               SELECT $1, v, t, d FROM unnest($2::int[], $3::text[], $4::jsonb[]) AS x(v, t, d)
               """,
               [stream, versions, Enum.map(records, & &1.type), Enum.map(records, & &1.data)]
             ) do
        List.last(versions)
      else
        {:ok, _} ->
          Postgrex.rollback(c, :wrong_expected_version)

        {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} ->
          Postgrex.rollback(c, :wrong_expected_version)

        {:error, e} ->
          raise e
      end
    end)
  end
end
