import Config

config :exircd,
  port: 6668,
  server_name: "test.irc.local",
  network_name: "TestNet",
  server_description: "Test IRC Server",
  debug_mode: false,
  operators: [
    %{
      name: "testop",
      password: "test123"
    }
  ]

config :logger,
  level: :warning
