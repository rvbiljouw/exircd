defmodule Exircd.Commands.Mode.ChannelMode do
  require Logger

  @supported_modes %{
    "i" => :invite_only,
    "t" => :topic_protected,
    "k" => :key,
    "l" => :limit
  }

  def execute(socket, _sender, ["#" <> _channel = channel | mode_args]) do
    with {:ok, _user} <- Exircd.Users.get_user_by_socket(socket) do
        handle_channel_mode(socket, channel, mode_args)
    end
  end

  def execute(socket, _sender, _) do
    :gen_tcp.send(socket, ":server 461 MODE :Not enough parameters\r\n")
    {:error, :not_enough_params}
  end

  defp handle_channel_mode(_socket, _channel, _modes) do
    {:error, :not_implemented}
  end

  def supported_modes, do: @supported_modes
end
