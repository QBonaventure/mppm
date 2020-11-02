defmodule Mppm.Statuses do
  use Agent
  alias Mppm.ServerConfigStore


  @allowed_statuses ["stopped", "starting", "started", "failed"]
  @default_statuses %{server: "stopped", controller: "stopped"}


  def start_link(_init_value) do
    logins =
      ServerConfigStore.logins
      |> Enum.map(& {&1, %{server: "stopped", controller: "stopped"}})
      |> Map.new
    Agent.start_link(fn-> logins end, name: __MODULE__)
  end


  def all() do
    Agent.get(__MODULE__, & &1)
  end

  def add_new_server(login) do
    Agent.update(__MODULE__, & Map.put_new(&1, login, @default_statuses))
  end


  def update_server(login, status) when status in @allowed_statuses do
    Phoenix.PubSub.broadcast(Mppm.PubSub, "server_status", :update)
    Agent.update(__MODULE__, & Kernel.put_in(&1, [login, :server], status))
  end


  def update_controller(login, status) when status in @allowed_statuses do
    Agent.update(__MODULE__, & Kernel.put_in(&1, [login, :controller], status))
  end


end
