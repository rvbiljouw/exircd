defmodule Exircd.Application do
  use Application

  def start(_type, _args) do
    port = String.to_integer(System.get_env("PORT") || "6667")

    children = [
      {Registry, keys: :unique, name: Exircd.CommandRegistry},
      {Registry, keys: :unique, name: Exircd.UserRegistry},
      {Registry, keys: :unique, name: Exircd.ChannelRegistry},
      {Exircd.Sessions, []},
      {Exircd.Channels, []},
      {Task, fn -> Exircd.Server.start(port) end}
    ]

    opts = [strategy: :one_for_one, name: Exircd.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
