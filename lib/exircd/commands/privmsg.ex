defmodule Exircd.Commands.Privmsg do
  require Logger

  def execute(socket, _sender, [target | message_parts]) do
    with {:ok, sender} <- Exircd.Users.get_user_by_socket(socket) do
      message = Enum.join(message_parts, " ")
      message = String.trim_leading(message, ":")

      case String.first(target) do
        "#" -> handle_channel_message(socket, sender, target, message)
        _ -> handle_private_message(socket, sender, target, message)
      end
    end
  end

  def execute(socket, _sender, _) do
    :gen_tcp.send(socket, ":server 411 :No recipient given (PRIVMSG)\r\n")
    {:error, :no_recipient}
  end

  defp handle_private_message(socket, sender, target_nick, message) do
    case Exircd.Users.get_user(target_nick) do
      {:error, :user_not_found} ->
        :gen_tcp.send(socket, ":server 401 #{target_nick} :No such nick/channel\r\n")
        {:error, :no_such_target}

      {:ok, target_user} ->
        formatted_message =
          ":#{sender.nickname}!#{sender.username}@#{sender.servername} PRIVMSG #{target_nick} :#{message}\r\n"

        :gen_tcp.send(target_user.socket, formatted_message)
        {:ok, message}
    end
  end

  defp handle_channel_message(socket, sender, channel_name, message) do
    case Exircd.Channels.get_channel(channel_name) do
      nil ->
        :gen_tcp.send(socket, ":server 403 #{channel_name} :No such channel\r\n")
        {:error, :no_such_channel}

      channel ->
        if MapSet.member?(channel.users, sender) do
          formatted_message =
            ":#{sender.nickname}!#{sender.username}@#{sender.servername} PRIVMSG #{channel_name} :#{message}\r\n"

          Exircd.Channels.broadcast(channel_name, formatted_message, sender)
          {:ok, message}
        else
          :gen_tcp.send(socket, ":server 404 #{channel_name} :Cannot send to channel\r\n")
          {:error, :not_in_channel}
        end
    end
  end
end
