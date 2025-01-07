defmodule Exircd.Commands.Topic do
  require Logger

  def execute(socket, _sender, [channel_name | topic_parts]) do
    with {:ok, user} <- Exircd.Users.get_user_by_socket(socket) do
      case Exircd.Channels.get_channel(channel_name) do
        nil ->
          :gen_tcp.send(socket, ":server 403 #{channel_name} :No such channel\r\n")
          {:error, :no_such_channel}

          channel ->
            if MapSet.member?(channel.users, user) do
              case topic_parts do
                [] ->
                  show_topic(socket, user, channel_name, channel.topic)

                topic_words ->
                  set_topic(socket, user, channel_name, topic_words, channel)
              end
            else
              :gen_tcp.send(socket, ":server 442 #{channel_name} :You're not on that channel\r\n")
              {:error, :not_in_channel}
            end
        end
    end
  end

  defp show_topic(socket, user, channel_name, topic) do
    case topic do
      nil ->
        :gen_tcp.send(socket, ":server 331 #{user.nickname} #{channel_name} :No topic is set\r\n")

      topic ->
        :gen_tcp.send(socket, ":server 332 #{user.nickname} #{channel_name} :#{topic}\r\n")
    end
    {:ok, topic}
  end

  defp set_topic(socket, user, channel_name, topic_words, channel) do
    if channel.modes["t"] && !MapSet.member?(channel.operators, user.nickname) do
      :gen_tcp.send(socket, ":server 482 #{channel_name} :You're not channel operator\r\n")
      {:error, :not_operator}
    else
      topic = topic_words |> Enum.join(" ") |> String.trim_leading(":")
      case Exircd.Channels.set_topic(channel_name, topic) do
        {:ok, _} ->
          msg = ":#{user.nickname}!#{user.username}@#{user.servername} TOPIC #{channel_name} :#{topic}\r\n"
          Exircd.Channels.broadcast(channel_name, msg)
          {:ok, topic}

        error -> error
      end
    end
  end
end
