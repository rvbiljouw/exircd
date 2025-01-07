defmodule Exircd.Commands.Part do
  require Logger

  def execute(socket, _sender, [channel_list | reason]) do
    with {:ok, user} <- Exircd.Users.get_user_by_socket(socket) do
      part_reason = if reason == [], do: "Leaving", else: Enum.join(reason, " ")

      channel_list
      |> String.split(",")
      |> Enum.each(fn channel ->
        part_channel(socket, user, channel, part_reason)
      end)

      {:ok, channel_list}
    end
  end

  defp part_channel(socket, user, channel_name, reason) do
    case Exircd.Channels.get_channel(channel_name) do
      nil ->
        :gen_tcp.send(socket, ":server 403 #{channel_name} :No such channel\r\n")

      channel ->
        if MapSet.member?(channel.users, user) do
          part_msg =
            ":#{user.nickname}!#{user.username}@#{user.servername} PART #{channel_name} :#{reason}\r\n"

          Exircd.Channels.broadcast(channel_name, part_msg)

          Exircd.Channels.part(channel_name, user)
        else
          :gen_tcp.send(socket, ":server 442 #{channel_name} :You're not on that channel\r\n")
        end
    end
  end
end
