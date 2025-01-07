defmodule Exircd.Commands.Who do
  @moduledoc """
  Implements the WHO command which provides information about users.
  Syntax: WHO <mask> [o]
  """

  alias Exircd.Users
  alias Exircd.Channels

  def execute(socket, _sender, [target | _opts]) do
    with {:ok, requesting_user} <- Users.get_user_by_socket(socket) do
      if String.starts_with?(target, "#") do
        handle_channel_who(socket, requesting_user, target)
      else
        handle_user_who(socket, requesting_user, target)
      end

      :gen_tcp.send(
        socket,
        ":#{server_name()} 315 #{requesting_user.nickname} #{target} :End of WHO list\r\n"
      )
    end
  end

  def execute(socket, _sender, _args) do
    :gen_tcp.send(socket, ":#{server_name()} 461 WHO :Not enough parameters\r\n")
  end

  defp handle_channel_who(socket, requesting_user, channel_name) do
    case Channels.get_channel(channel_name) do
      nil ->
        :ok

      channel ->
        # Send WHO reply for each user in channel
        Enum.each(channel.users, fn user ->
          send_who_reply(socket, requesting_user, user, channel_name)
        end)
    end
  end

  defp handle_user_who(socket, requesting_user, mask) do
    # TODO: Implement proper mask matching
    case Users.get_user(mask) do
      {:ok, target_user} ->
        send_who_reply(socket, requesting_user, target_user, "*")

      _ ->
        :ok
    end
  end

  defp send_who_reply(socket, requesting_user, target_user, channel) do
    flags = if is_operator?(target_user), do: "H*", else: "H"

    reply =
      ":#{server_name()} 352 #{requesting_user.nickname} #{channel} #{target_user.username} " <>
        "#{target_user.hostname} #{server_name()} #{target_user.nickname} #{flags} :0 #{target_user.realname}\r\n"

    :gen_tcp.send(socket, reply)
  end

  defp is_operator?(user) do
    Application.get_env(:exircd, :operators, [])
    |> Enum.any?(fn op -> op.name == user.username end)
  end

  defp server_name, do: Application.get_env(:exircd, :server_name, "irc.local")
end
