defmodule Exircd.Users do
  require Logger

  @registry Exircd.UserRegistry

  def start_link do
    Registry.start_link(keys: :unique, name: @registry)
  end

  def register(socket, nickname, username, realname, servername) do
    user = %{
      socket: socket,
      nickname: nickname,
      username: username,
      realname: realname,
      servername: servername,
      registered_at: DateTime.utc_now(),
      channels: MapSet.new()
    }

    case Registry.register(@registry, String.downcase(nickname), user) do
      {:ok, _} -> {:ok, user}
      {:error, {:already_registered, _}} -> {:error, :nickname_in_use}
    end
  end

  def get_user(nickname) do
    case Registry.lookup(@registry, String.downcase(nickname)) do
      [{_pid, user}] ->
        {:ok, user}
      [] ->
        {:error, :user_not_found}
    end
  end

  def get_user_by_socket(socket) do
    @registry
    |> Registry.select([{
      {:"$1", :_, :"$2"},
      [{:==, {:map_get, :socket, :"$2"}, {:const, socket}}],
      [:"$2"]
    }])
    |> case do
      [user] ->
        {:ok, user}
      [] ->
        {:error, :not_registered}
    end
  end

  def broadcast(message, exclude_socket \\ nil) do
    @registry
    |> Registry.select([{
      {:"$1", :"$2", %{socket: :"$3"}},
      [],
      [:"$3"]
    }])
    |> Enum.each(fn socket ->
      if socket != exclude_socket do
        :gen_tcp.send(socket, message)
      end
    end)
  end

  def remove_user(socket) do
    @registry
    |> Registry.select([{
      {:"$1", :"$2", %{socket: socket}},
      [],
      [:"$1"]
    }])
    |> case do
      [nickname] ->
        Registry.unregister(@registry, nickname)
      [] ->
        :ok
    end
  end

  def format_user_mask(nickname, username, host) do
    "#{nickname}!#{username}@#{host}"
  end
end
