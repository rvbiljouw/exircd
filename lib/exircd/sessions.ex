defmodule Exircd.Sessions do
  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def create(socket) do
    GenServer.call(__MODULE__, {:create, socket})
  end

  def update(socket, key, value) do
    GenServer.call(__MODULE__, {:update, socket, key, value})
  end

  def get(socket) do
    GenServer.call(__MODULE__, {:get, socket})
  end

  def remove(socket) do
    GenServer.cast(__MODULE__, {:remove, socket})
  end

  def try_register(socket) do
    GenServer.call(__MODULE__, {:try_register, socket})
  end

  def update_modes(socket, action, modes) do
    GenServer.call(__MODULE__, {:update_modes, socket, action, modes})
  end

  def has_mode?(socket, mode) do
    case get(socket) do
      %{modes: modes} -> MapSet.member?(modes, mode)
      _ -> false
    end
  end

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:create, socket}, _from, state) do
    session = %{
      nickname: nil,
      username: nil,
      realname: nil,
      registered: false,
      capabilities: [],
      modes: MapSet.new()
    }

    {:reply, :ok, Map.put(state, socket, session)}
  end

  def handle_call({:update, socket, key, value}, _from, state) do
    new_state = update_in(state, [socket], fn session ->
      session = session || %{}
      Map.put(session, key, value)
    end)

    {:reply, :ok, new_state}
  end

  def handle_call({:get, socket}, _from, state) do
    {:reply, Map.get(state, socket), state}
  end

  def handle_call({:try_register, socket}, _from, state) do
    case Map.get(state, socket) do
      %{nickname: nickname, username: username, realname: realname, servername: servername, registered: false} ->
        case Exircd.Users.register(socket, nickname, username, realname, servername) do
          {:ok, user} ->
            new_state = put_in(state[socket][:registered], true)
            {:reply, {:ok, user}, new_state}

          {:error, _} = error ->
            {:reply, error, state}
        end

      %{registered: true} ->
        {:reply, {:error, :already_registered}, state}

      _ ->
        {:reply, {:error, :incomplete_registration}, state}
    end
  end

  def handle_call({:update_modes, socket, :add, modes}, _from, state) do
    new_state = update_in(state, [socket, :modes], fn current_modes ->
      modes
      |> String.graphemes()
      |> Enum.reduce(current_modes, &MapSet.put(&2, &1))
    end)

    {:reply, :ok, new_state}
  end

  def handle_call({:update_modes, socket, :remove, modes}, _from, state) do
    new_state = update_in(state, [socket, :modes], fn current_modes ->
      modes
      |> String.graphemes()
      |> Enum.reduce(current_modes, &MapSet.delete(&2, &1))
    end)

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast({:remove, socket}, state) do
    {:noreply, Map.delete(state, socket)}
  end

end
