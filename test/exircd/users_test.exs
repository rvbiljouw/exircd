defmodule Exircd.UsersTest do
  use ExUnit.Case
  alias Exircd.Users

  setup do
    case Users.start_link() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
    :ok
  end

  test "register/5 creates a new user" do
    socket = make_ref() # Mock socket for testing
    assert {:ok, user} = Users.register(socket, "tester", "test", "Test User", "test.server")
    assert user.nickname == "tester"
    assert user.username == "test"
  end

  test "get_user/1 finds user by nickname" do
    socket = make_ref()
    {:ok, created_user} = Users.register(socket, "tester", "test", "Test User", "test.server")
    assert {:ok, found_user} = Users.get_user("tester")
    assert created_user.nickname == found_user.nickname
  end

  test "remove_user/1 removes a user" do
    socket = make_ref()
    {:ok, _user} = Users.register(socket, "tester", "test", "Test User", "test.server")
    assert :ok = Users.remove_user(socket)
    assert {:error, :user_not_found} = Users.get_user("tester")
  end

  test "get_user_by_socket/1 finds user by socket" do
    socket = make_ref()
    {:ok, created_user} = Users.register(socket, "tester", "test", "Test User", "test.server")
    assert {:ok, found_user} = Users.get_user_by_socket(socket)
    assert created_user.nickname == found_user.nickname
  end
end
