defmodule AccountabotWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :accountabot

  @session_options [
    store: :cookie,
    key: "_accountabot_key",
    signing_salt: "cpa-session",
    same_site: "Lax"
  ]

  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])

  # The LiveView client ships prebuilt in the deps; serving it directly avoids a JS toolchain.
  plug(Plug.Static,
    at: "/assets/phoenix",
    from: {:phoenix, "priv/static"},
    only: ~w(phoenix.min.js)
  )

  plug(Plug.Static,
    at: "/assets/live_view",
    from: {:phoenix_live_view, "priv/static"},
    only: ~w(phoenix_live_view.min.js)
  )

  plug(Plug.RequestId)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(AccountabotWeb.Router)
end
