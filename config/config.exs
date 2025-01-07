import Config

# Common configuration used across all environments
config :exircd,
  server_name: "irc.local",
  network_name: "ExIRCd",
  server_description: "ExIRCd IRC Server",
  port: 6667,
  operators: [
    %{
      name: "admin",
      password: "change_me"
    }
  ]

# Import environment specific config
import_config "#{config_env()}.exs"
