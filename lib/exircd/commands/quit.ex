defmodule Exircd.Commands.Quit do
  require Logger

  def execute(socket, _sender, message) when is_list(message) do
    handle_quit(socket, message |> Enum.join(" "))
  end

  def execute(socket, _sender, []) do
    handle_quit(socket, "Client exited")
  end

  defp handle_quit(socket, message) do
    with {:ok, user} <- Exircd.Users.get_user_by_socket(socket) do
      quit_msg = ":#{user.nickname}!#{user.username}@#{user.servername} QUIT :#{message}\r\n"
      Exircd.Users.broadcast(quit_msg, socket)

      :gen_tcp.close(socket)

      Exircd.Users.remove_user(socket)
      Exircd.Sessions.remove(socket)

      {:ok, :quit}
    end
  end
end
