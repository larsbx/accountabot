import Config

config :accountabot, AccountabotWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  render_errors: [formats: [html: AccountabotWeb.ErrorHTML], layout: false],
  pubsub_server: Accountabot.PubSub,
  live_view: [signing_salt: "cpa-review"]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
