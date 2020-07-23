defmodule Mppm.GameServer.Chat do
  use GenServer


  def child_spec(ServerConfig{} = server_config) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[server_config], []]},
      restart: :transient,
      name: {:global, {:server_chat, server_config.login}}
    }
  end

end
