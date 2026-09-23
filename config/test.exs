import Config

config :accountabot, store: :memory

config :accountabot, AccountabotWeb.Endpoint,
  http: [port: 4002],
  server: false,
  secret_key_base: String.duplicate("test-only-not-secret-", 4)

config :logger, level: :warning
