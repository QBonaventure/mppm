defmodule Mppm.ServerConfigStore do
  use Agent
  alias __MODULE__
  alias Mppm.{ServerConfig,Repo}
  import Ecto.Query


  def start_link(_init_value) do
    configs = Repo.all(from(ServerConfig))
    Agent.start_link(fn-> configs end, name: __MODULE__)
  end

  def all() do
    Agent.get(__MODULE__, & &1)
  end

  def logins() do
    Agent.get(__MODULE__, fn configs -> Enum.map(configs, & &1.login) end)
  end


  # def create(%ServerConfig{} = server_config) do
  #   Agent.start_link(fn -> ServerConfig end, name: {:global, {:server_config, server_config.name}})
  # end
  #
  #
  #
  # def get(key) do
  #   case :global.whereis_name({:server_config, key}) do
  #     :undefined -> nil
  #     _pid -> Agent.get({:global, {:server_config, key}}, & &1)
  #   end
  # end
  #
  # def update(key, %ServerConfig{} = new_state) do
  #   case :global.whereis_name({:server_config, key}) do
  #     :undefined -> nil
  #     pid -> Agent.update({:global, {:server_config, key}}, fn state -> new_state end)
  #   end
  # end

end
