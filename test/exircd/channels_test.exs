defmodule Exircd.ChannelsTest do
  use ExUnit.Case
  alias Exircd.Channels
  alias Exircd.Users

  setup do
    Users.start_link()
    case Channels.start_link([]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    GenServer.call(Channels, :clear)

    socket = make_ref()
    {:ok, user} = Users.register(socket, "tester", "test", "Test User", "test.server")

    {:ok, user: user}
  end

  test "create/2 creates a new channel", %{user: user} do
    assert {:ok, channel} = Channels.create("#test", user)
    assert channel.name == "#test"
    assert channel.topic == nil
    assert MapSet.member?(channel.users, user)
  end

  test "join/2 adds user to channel", %{user: user} do
    {:ok, _channel} = Channels.create("#test", user)

    socket2 = make_ref()
    {:ok, user2} = Users.register(socket2, "tester2", "test2", "Test User 2", "test.server")

    assert {:ok, updated_channel} = Channels.join("#test", user2)
    assert MapSet.member?(updated_channel.users, user2)
  end

  test "part/2 removes user from channel", %{user: user} do
    {:ok, _channel} = Channels.create("#test", user)
    assert {:ok, updated_channel} = Channels.part("#test", user)
    refute MapSet.member?(updated_channel.users, user)
  end

  test "set_topic/2 updates channel topic", %{user: user} do
    {:ok, _channel} = Channels.create("#test", user)
    assert {:ok, updated_channel} = Channels.set_topic("#test", "New topic")
    assert updated_channel.topic == "New topic"
  end

  test "list_channels/0 lists all channels", %{user: user} do
    {:ok, created_channel} = Channels.create("#test", user)
    channels = Channels.list_channels()
    assert Enum.find(channels, &(&1.name == created_channel.name)) != nil
  end
end
