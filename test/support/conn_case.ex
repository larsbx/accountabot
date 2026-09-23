defmodule AccountabotWeb.ConnCase do
  @moduledoc "LiveView test case over the app's store. Each test uses a fresh CPA id for isolation."
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint AccountabotWeb.Endpoint
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import AccountabotWeb.ConnCase, only: [onboard: 2]
      use Phoenix.VerifiedRoutes, endpoint: AccountabotWeb.Endpoint, router: AccountabotWeb.Router
    end
  end

  setup do
    {:ok,
     conn: Phoenix.ConnTest.build_conn(),
     cpa: "cpa-#{Base.encode16(:crypto.strong_rand_bytes(6))}"}
  end

  def onboard(cpa, answers) do
    for {q, v} <- answers,
        do: {:ok, _, _} = Accountabot.Cpas.answer(Accountabot.store(), cpa, q, v)

    :ok
  end
end
