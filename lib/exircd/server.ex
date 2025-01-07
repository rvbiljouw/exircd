defmodule Exircd.Server do
  require Logger

  def start(port) do
    {:ok, socket} =
      :gen_tcp.listen(port, [
        :binary,
        packet: :line,
        active: false,
        reuseaddr: true
      ])

    Logger.info("Started IRC server on port #{port}")
    accept_connections(socket)
  end

  defp accept_connections(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    Exircd.Sessions.create(client)

    {:ok, pid} = Task.start(fn -> handle_client(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)

    accept_connections(socket)
  end

  defp handle_client(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        data = String.trim(data)
        handle_message(socket, data)
        handle_client(socket)

      {:error, :closed} ->
        Logger.info("Client disconnected")
        cleanup_connection(socket)
        :ok

      {:error, :enotconn} ->
        Logger.info("Connection lost")
        cleanup_connection(socket)
        :ok
    end
  end

  defp handle_message(socket, data) do
    [command, params] = String.split(data, " ", parts: 2)
    tokenized_params = String.split(params, " ", trim: true)

    case Exircd.Commands.handle_command(socket, command, tokenized_params) do
      {:error, :not_registered} ->
        :gen_tcp.send(socket, ":server 451 :You have not registered\r\n")

      {:error, reason} ->
        :gen_tcp.send(socket, ":server 400 :#{reason}\r\n")

      _ ->
        :ok
    end
  end

  defp cleanup_connection(socket) do
    Exircd.Users.remove_user(socket)
    Exircd.Sessions.remove(socket)
  end
end
