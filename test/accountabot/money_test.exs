defmodule Accountabot.MoneyTest do
  use ExUnit.Case, async: true
  doctest Accountabot.Money

  test "formats edge cases" do
    assert Enum.map([0, 5, 100, 100_000, -1_234_56], &Accountabot.Money.format/1) ==
             ["$0.00", "$0.05", "$1.00", "$1,000.00", "-$1,234.56"]
  end
end
