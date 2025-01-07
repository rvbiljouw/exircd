defmodule Exircd.Channels do
  use GenServer
  require Logger

  @registry Exircd.ChannelRegistry

  # Client API
  def start_link(_opts) do
    Registry.start_link(keys: :unique, name: @registry)
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def create(channel_name, creator) do
    GenServer.call(__MODULE__, {:create, channel_name, creator})
  end

  def join(channel_name, user, key \\ nil) do
    GenServer.call(__MODULE__, {:join, channel_name, user, key})
  end

  def part(channel_name, user) do
    GenServer.call(__MODULE__, {:part, channel_name, user})
  end

  def broadcast(channel_name, message, exclude_user \\ nil) do
    GenServer.cast(__MODULE__, {:broadcast, channel_name, message, exclude_user})
  end

  def get_channel(channel_name) do
    case Registry.lookup(@registry, String.downcase(channel_name)) do
      [{_pid, channel}] -> channel
      [] -> nil
    end
  end

  def list_channels do
    GenServer.call(__MODULE__, :list_channels)
  end

  def set_mode(channel_name, mode, value \\ nil) do
    GenServer.call(__MODULE__, {:set_mode, channel_name, mode, value})
  end

  def set_topic(channel_name, topic) do
    GenServer.call(__MODULE__, {:set_topic, channel_name, topic})
  end

  # Server Callbacks
  @impl true
  def init(_) do
    {:ok, %{}}  # channel_name => channel_data
  end

  @impl true
  def handle_call({:create, channel_name, creator}, _from, state) do
    case do_create_channel(channel_name, creator) do
      {:ok, channel} -> {:reply, {:ok, channel}, state}
      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:join, channel_name, user, key}, _from, state) do
    case get_channel(channel_name) do
      nil ->
        # Create channel if it doesn't exist
        case do_create_channel(channel_name, user) do
          {:ok, channel} -> {:reply, {:ok, channel}, state}
          error -> {:reply, error, state}
        end

      channel ->
        case do_join_channel(channel, channel_name, user, key) do
          {:ok, new_channel} -> {:reply, {:ok, new_channel}, state}
          error -> {:reply, error, state}
        end
    end
  end

  @impl true
  def handle_call({:part, channel_name, user}, _from, state) do
    case get_channel(channel_name) do
      nil ->
        {:reply, {:error, :no_such_channel}, state}

      channel ->
        case do_part_channel(channel, channel_name, user) do
          {:ok, new_channel} -> {:reply, {:ok, new_channel}, state}
          error -> {:reply, error, state}
        end
    end
  end

  @impl true
  def handle_call({:set_topic, channel_name, topic}, _from, state) do
    case get_channel(channel_name) do
      nil ->
        {:reply, {:error, :no_such_channel}, state}

      channel ->
        case do_set_topic(channel, channel_name, topic) do
          {:ok, new_channel} -> {:reply, {:ok, new_channel}, state}
          error -> {:reply, error, state}
        end
    end
  end

  @impl true
  def handle_call(:list_channels, _from, state) do
    channels = Registry.select(@registry, [{{:"$1", :"$2", :"$3"}, [], [:"$3"]}])
    {:reply, channels, state}
  end

  @impl true
  def handle_call(:clear, _from, _state) do
    Registry.keys(@registry, self())
    |> Enum.each(&Registry.unregister(@registry, &1))
    {:reply, :ok, %{}}
  end

  @impl true
  def handle_cast({:broadcast, channel_name, message, exclude_user}, state) do
    case get_channel(channel_name) do
      nil ->
        :ok

      channel ->
        do_broadcast(channel, message, exclude_user)
    end

    {:noreply, state}
  end

  # Private functions for core operations
  defp do_create_channel(channel_name, creator) do
    channel = %{
      name: channel_name,
      topic: nil,
      modes: %{},
      users: MapSet.new([creator]),
      operators: MapSet.new([creator.nickname]),
      created_at: DateTime.utc_now()
    }

    case Registry.register(@registry, String.downcase(channel_name), channel) do
      {:ok, _} -> {:ok, channel}
      {:error, {:already_registered, _}} -> {:error, :channel_exists}
    end
  end

  defp do_join_channel(channel, channel_name, user, key) do
    cond do
      has_mode?(channel, "i") and not invited?(channel, user) ->
        {:error, :invite_only}

      has_mode?(channel, "k") and key != get_mode_value(channel, "k") ->
        {:error, :wrong_key}

      has_mode?(channel, "l") and channel.users |> MapSet.size() >= get_mode_value(channel, "l") ->
        {:error, :channel_full}

      true ->
        new_channel = update_in(channel.users, &MapSet.put(&1, user))
        Registry.update_value(@registry, String.downcase(channel_name), fn _ -> new_channel end)
        {:ok, new_channel}
    end
  end

  defp do_part_channel(channel, channel_name, user) do
    new_channel = update_in(channel.users, &MapSet.delete(&1, user))
    Registry.update_value(@registry, String.downcase(channel_name), fn _ -> new_channel end)
    {:ok, new_channel}
  end

  defp do_set_topic(channel, channel_name, topic) do
    new_channel = %{channel | topic: topic}
    Registry.update_value(@registry, String.downcase(channel_name), fn _ -> new_channel end)
    {:ok, new_channel}
  end

  defp do_broadcast(channel, message, exclude_user) do
    channel.users
    |> Enum.reject(&(&1 == exclude_user))
    |> Enum.each(fn user ->
      :gen_tcp.send(user.socket, message)
    end)
  end

  # Helper functions
  defp has_mode?(channel, mode), do: Map.has_key?(channel.modes, mode)

  defp get_mode_value(channel, mode), do: Map.get(channel.modes, mode)

  defp invited?(_channel, _user) do
    # To be implemented with invite tracking
    false
  end

  def is_operator?(channel, user) do
    MapSet.member?(channel.operators, user.nickname)
  end

  def user_in_channel?(channel, user) do
    MapSet.member?(channel.users, user)
  end
end
