import Config

if config_env() == :prod do
  config :accountabot, AccountabotWeb.Endpoint,
    server: true,
    url: [host: System.fetch_env!("PHX_HOST"), scheme: "https", port: 443],
    http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT", "4000"))],
    secret_key_base: System.fetch_env!("SECRET_KEY_BASE")
end
