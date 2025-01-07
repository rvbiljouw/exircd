import Config

if config_env() == :prod do
  config :exircd,
    port: String.to_integer(System.get_env("IRC_PORT", "6667")),
    server_name: System.get_env("IRC_SERVER_NAME", "irc.local"),
    network_name: System.get_env("IRC_NETWORK_NAME", "ExIRCd"),
    server_description: System.get_env("IRC_SERVER_DESC", "ExIRCd IRC Server"),
    operators: [
      %{
        name: System.get_env("IRC_OPER_NAME", "admin"),
        password: System.fetch_env!("IRC_OPER_PASSWORD")
      }
    ]
end
