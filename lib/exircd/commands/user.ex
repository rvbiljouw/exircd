defmodule Exircd.Commands.User do
  @server_version "0.1.0"
  # i = invisible
  @user_modes "i"
  # i = invite-only, t = topic protection, k = key, l = limit
  @channel_modes "itkl"

  def execute(socket, _sender, [username, _mode, _unused | realname_parts]) do
    # Combine all remaining parts as realname (might start with *)
    realname = realname_parts |> Enum.join(" ") |> String.trim_leading(":")
    # Use localhost as default servername
    servername = "localhost"

    Exircd.Sessions.update(socket, :username, username)
    Exircd.Sessions.update(socket, :realname, realname)
    Exircd.Sessions.update(socket, :servername, servername)

    case Exircd.Sessions.get(socket) do
      %{nickname: nil} ->
        {:ok, username}

      %{nickname: nickname, registered: false} ->
        case Exircd.Users.register(socket, nickname, username, realname, servername) do
          {:ok, user} ->
            Exircd.Sessions.update(socket, :registered, true)

            :gen_tcp.send(socket, """
            :server 001 #{user.nickname} :Welcome to the IRC Network
            :server 002 #{user.nickname} :Your host is #{servername}, running Exircd
            :server 003 #{user.nickname} :This server was created #{user.registered_at}
            :server 004 #{user.nickname} #{servername} #{@server_version} #{@user_modes} #{@channel_modes}\r\n
            """)

            {:ok, user}

          {:error, :nickname_in_use} ->
            :gen_tcp.send(socket, ":server 433 * #{nickname} :Nickname is already in use\r\n")
            Exircd.Sessions.update(socket, :nickname, nil)
            {:error, :nickname_in_use}
        end

      %{registered: true} ->
        :gen_tcp.send(socket, ":server 462 :You may not reregister\r\n")
        {:error, :already_registered}
    end
  end

  def execute(socket, _sender, _) do
    :gen_tcp.send(socket, ":server 461 USER :Not enough parameters\r\n")
    {:error, :invalid_params}
  end
end
