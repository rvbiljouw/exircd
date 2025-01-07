defmodule Exircd.Commands.Mode do
  alias __MODULE__.{UserMode, ChannelMode}

  def execute(socket, sender, [target | _] = args) do
    case String.first(target) do
      "#" -> ChannelMode.execute(socket, sender, args)
      _ -> UserMode.execute(socket, sender, args)
    end
  end

  def execute(socket, sender, args) do
    UserMode.execute(socket, sender, args)
  end
end
