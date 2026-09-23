import Config

config :accountabot, store: :memory, seed_demo: "demo"

config :accountabot, AccountabotWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  server: true,
  debug_errors: true,
  secret_key_base: String.duplicate("dev-only-not-secret-", 4)
