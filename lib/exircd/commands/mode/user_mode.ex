defmodule Exircd.Commands.Mode.UserMode do
  require Logger

  @supported_modes ["i"]

  def execute(socket, _sender, [nickname | mode_args]) do
    with {:ok, user} <- Exircd.Users.get_user_by_socket(socket) do
      if user.nickname != nickname do
        :gen_tcp.send(socket, ":server 502 :Cant change mode for other users\r\n")
        {:error, :not_authorized}
      else
        handle_mode_change(socket, nickname, mode_args)
      end
    end
  end

  def execute(socket, _sender, _) do
    :gen_tcp.send(socket, ":server 461 MODE :Not enough parameters\r\n")
    {:error, :not_enough_params}
  end

  defp handle_mode_change(socket, nickname, [mode_string | _]) do
    {action, mode} = parse_mode_string(mode_string)

    if mode in @supported_modes do
      Exircd.Sessions.update_modes(socket, action, mode)
      :gen_tcp.send(socket, ":#{nickname} MODE #{nickname} #{mode_string}\r\n")
      {:ok, mode}
    else
      :gen_tcp.send(socket, ":server 501 :Unknown MODE flag\r\n")
      {:error, :unknown_mode}
    end
  end

  defp handle_mode_change(socket, nickname, []) do
    case Exircd.Sessions.get(socket) do
      %{modes: modes} when modes != %MapSet{} ->
        mode_string = "+#{Enum.join(modes)}"
        :gen_tcp.send(socket, ":server MODE #{nickname} :#{mode_string}\r\n")
        {:ok, mode_string}

      _ ->
        {:ok, :no_modes}
    end
  end

  defp parse_mode_string("+" <> modes), do: {:add, modes}
  defp parse_mode_string("-" <> modes), do: {:remove, modes}
  defp parse_mode_string(modes), do: {:add, modes}
end
