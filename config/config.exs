import Config

if config_env() != :test, do: config(:accountabot, db: [])
