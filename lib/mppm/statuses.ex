defmodule Mppm.ServersStatuses do
  use Agent
  alias Mppm.ServerConfig


  @allowed_statuses [:stopping, :stopped, :starting, :started, :failed]

  def fetch_all_configs(), do:
    Mppm.Repo.all(Mppm.ServerConfig) |> Mppm.Repo.preload([ruleset: [:mode]])


  def all() do
    Agent.get(__MODULE__, & &1)
  end

  def get_list_of_running() do
    Agent.get(__MODULE__, & &1)
    |> Enum.filter(& elem(&1, 1).status == :started)
    |> Enum.map(& elem(&1, 0))
  end

  def get_start_flag(server_login) do
    case get_server_status(server_login) do
      :stopped ->
        update_server_status(server_login, :starting)
        :ok
      status -> status
    end
  end

  def get_stop_flag(server_login) do
    case get_server_status(server_login) do
      :started ->
        update_server_status(server_login, :stopping)
        :ok
      status -> status
    end
  end


  def get_statuses_list(), do: @allowed_statuses

  def get_server_config(server_login), do: Agent.get(__MODULE__, & &1[server_login].config)

  def get_server_status(server_login), do: Agent.get(__MODULE__, & &1[server_login].status)


  def is_stopped?(server_login), do: :stopped == get_server_status(server_login)

  def add_new_server(%ServerConfig{ruleset: %Ecto.Association.NotLoaded{}} = server_config), do:
    server_config |> Mppm.Repo.preload(ruleset: [:mode]) |> add_new_server()
  def add_new_server(%ServerConfig{ruleset: %Mppm.GameRules{mode: %Ecto.Association.NotLoaded{}}} = server_config), do:
    server_config |> Mppm.Repo.preload(ruleset: [:mode]) |> add_new_server()
  def add_new_server(%ServerConfig{} = server_config), do:
    Agent.update(__MODULE__, & Map.put_new(&1, server_config.login, %{config: &1, next_config: nil, status: :stopped}))


  def update_server_status(login, status) when status in @allowed_statuses do
    Agent.update(__MODULE__, & Kernel.put_in(&1, [login, :status], status))
    Phoenix.PubSub.broadcast(Mppm.PubSub, "server-status", {status, login})
  end



  def start_link(_init_value) do
    servers =
      fetch_all_configs
      |> Enum.map(& {&1.login, %{config: &1, next_config: nil, status: :stopped}})
      |> Map.new
    Agent.start_link(fn-> servers end, name: __MODULE__)
  end


end
