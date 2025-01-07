defmodule Exircd.Commands.Join do
  require Logger

  def execute(socket, _sender, [channel_list | keys]) do
    with {:ok, user} <- Exircd.Users.get_user_by_socket(socket) do
      channels = String.split(channel_list, ",")

      keys =
        case keys do
          [key_list] -> String.split(key_list, ",")
          [] -> []
        end

      Enum.zip(channels, Stream.concat(keys, Stream.cycle([nil])))
      |> Enum.reduce({:ok, []}, fn {channel, key}, {status, joined} ->
        case join_channel(socket, user, channel, key) do
          {:ok, _} -> {status, [channel | joined]}
          error -> {error, joined}
        end
      end)
    end
  end

  defp join_channel(socket, user, channel, key) do
    case Exircd.Channels.join(channel, user, key) do
      {:ok, channel_data} ->
        :gen_tcp.send(
          socket,
          ":#{user.nickname}!#{user.username}@#{user.servername} JOIN #{channel}\r\n"
        )

        if channel_data.topic do
          :gen_tcp.send(
            socket,
            ":server 332 #{user.nickname} #{channel} :#{channel_data.topic}\r\n"
          )
        end

        names =
          channel_data.users
          |> Enum.map(&format_user_prefix(channel_data, &1))
          |> Enum.join(" ")

        :gen_tcp.send(socket, ":server 353 #{user.nickname} = #{channel} :#{names}\r\n")
        :gen_tcp.send(socket, ":server 366 #{user.nickname} #{channel} :End of /NAMES list\r\n")

        join_msg = ":#{user.nickname}!#{user.username}@#{user.servername} JOIN #{channel}\r\n"
        Exircd.Channels.broadcast(channel, join_msg, user)

        {:ok, channel}

      {:error, :invite_only} ->
        :gen_tcp.send(socket, ":server 473 #{channel} :Cannot join channel (+i)\r\n")
        {:error, "invite_only"}

      {:error, :wrong_key} ->
        :gen_tcp.send(socket, ":server 475 #{channel} :Cannot join channel (+k)\r\n")
        {:error, "wrong_key"}

      {:error, :channel_full} ->
        :gen_tcp.send(socket, ":server 471 #{channel} :Cannot join channel (+l)\r\n")
        {:error, "channel_full"}
    end
  end

  defp format_user_prefix(channel, user) do
    prefix = if Exircd.Channels.is_operator?(channel, user), do: "@", else: ""
    "#{prefix}#{user.nickname}"
  end
end
