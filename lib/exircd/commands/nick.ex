defmodule Exircd.Commands.Nick do
  require Logger

  def execute(socket, _sender, [nickname]) do
    case Exircd.Users.get_user(nickname) do
      {:error, :user_not_found} ->
        Exircd.Sessions.update(socket, :nickname, nickname)
        :ok

      _user ->
        response = ":server 433 * #{nickname} :Nickname is already in use\r\n"
        :gen_tcp.send(socket, response)
        {:error, :nickname_in_use}
    end
  end

  def execute(socket, _sender, _) do
    :gen_tcp.send(socket, ":server 431 :No nickname given\r\n")
    {:error, :invalid_params}
  end
end
