defmodule Mppm.ServerConfigStore do
  alias __MODULE__
  alias Mppm.ServerConfig

  def create(%ServerConfig{} = server_config) do
    Agent.start_link(fn -> ServerConfig end, name: {:global, {:server_config, server_config.name}})
  end

  def get(key) do
    case :global.whereis_name({:server_config, key}) do
      :undefined -> nil
      _pid -> Agent.get({:global, {:server_config, key}}, & &1)
    end
  end

  def update(key, %ServerConfig{} = new_state) do
    case :global.whereis_name({:server_config, key}) do
      :undefined -> nil
      pid -> Agent.update({:global, {:server_config, key}}, fn state -> new_state end)
    end
  end

end
