import Config

config :exircd,
  debug_mode: true,
  log_level: :debug

config :logger, :console,
  format: "[$level] $message\n",
  level: :debug
