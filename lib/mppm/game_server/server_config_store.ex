defmodule Mppm.ServerConfigStore do
  use Agent
  alias Mppm.{ServerConfig,Repo}
  import Ecto.Query


  def start_link(_init_value) do
    configs = Repo.all(ServerConfig) |> Repo.preload(ruleset: [:mode])
    Agent.start_link(fn-> configs end, name: __MODULE__)
  end

  def all() do
    Agent.get(__MODULE__, & &1)
  end

  def logins() do
    Agent.get(__MODULE__, fn configs -> Enum.map(configs, & &1.login) end)
  end

end
