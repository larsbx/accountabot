defmodule Accountabot.EventStore.MemoryTest do
  use ExUnit.Case, async: true

  use Accountabot.EventStoreContract,
    store: fn ->
      {Accountabot.EventStore.Memory, start_supervised!(Accountabot.EventStore.Memory)}
    end
end
