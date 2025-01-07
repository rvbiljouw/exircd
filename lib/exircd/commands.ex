defmodule Exircd.Commands do
  require Logger
  alias Exircd.Commands.{Nick, User, Mode, Quit, Privmsg, Part, Topic, Join, Who}

  def handle_command(socket, "CAP", ["LS", _version]) do
    # no extra capabilities for now
    :gen_tcp.send(socket, "CAP * LS :\r\n")
  end

  def handle_command(_socket, "CAP", ["END"]) do
    # Client is done with capability negotiation
    :ok
  end

  def handle_command(socket, "NICK", args) do
    Nick.execute(socket, "*", args)
  end

  def handle_command(socket, "USER", args) do
    User.execute(socket, "*", args)
  end

  def handle_command(socket, "MODE", args) do
    Mode.execute(socket, "*", args)
  end

  def handle_command(socket, "PING", [payload]) do
    :gen_tcp.send(socket, "PONG #{payload}\r\n")
  end

  def handle_command(socket, "WHOIS", [nickname]) do
    case Exircd.Users.get_user(nickname) do
      {:error, :user_not_found} ->
        :gen_tcp.send(socket, ":server 401 * #{nickname} :No such nick\r\n")

      {:ok, user} ->
        :gen_tcp.send(
          socket,
          ":server 311 * #{user.nickname} #{user.username} localhost * :#{user.realname}\r\n"
        )

        :gen_tcp.send(socket, ":server 318 * #{nickname} :End of /WHOIS list\r\n")
    end
  end

  def handle_command(socket, "QUIT", args) do
    Quit.execute(socket, "*", args)
  end

  def handle_command(socket, "PRIVMSG", args) do
    Privmsg.execute(socket, "*", args)
  end

  def handle_command(socket, "ISON", nicknames) do
    online_nicks =
      nicknames
      |> Enum.filter(&Exircd.Users.get_user/1)
      |> Enum.join(" ")

    :gen_tcp.send(socket, ":server 303 * :#{online_nicks}\r\n")
    {:ok, online_nicks}
  end

  def handle_command(socket, "PART", args) do
    Part.execute(socket, "*", args)
  end

  def handle_command(socket, "TOPIC", args) do
    Topic.execute(socket, "*", args)
  end

  def handle_command(socket, "JOIN", args) do
    Join.execute(socket, "*", args)
  end

  def handle_command(socket, "WHO", args) do
    Who.execute(socket, "*", args)
  end

  def handle_command(socket, command, params) do
    Logger.error("Unknown command: #{inspect(command)} #{inspect(params)}")
    :gen_tcp.send(socket, ":server 421 * #{command} :Unknown command\r\n")
  end
end
