defmodule Mppm.GameServer.Supervisor do
  alias Mppm.ServerConfig


  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(%{id: Mppm.GameServer.Server} = mps_spec) do
    {:ok, _child_pid} = DynamicSupervisor.start_child(__MODULE__, mps_spec)
  end

  def start_child(%{id: Mppm.Broker.Supervisor} = broker_spec) do
    {:ok, _child_pid} = DynamicSupervisor.start_child(__MODULE__, broker_spec)
  end

  def start_server_supervisor(%ServerConfig{} = server_config) do
    {:ok, mp_server_pid} =
      Mppm.GameServer.Server.child_spec(server_config)
      |> Mppm.GameServer.Supervisor.start_child
    :ok = Mppm.ServersStatuses.add_new_server(server_config)
    {:ok, mp_server_pid}
  end

  def stop_mp_server(server_id) do
    {:ok, _mps_pid} = GenServer.call({:global, {:game_server, server_id}}, :stop)
    {:ok}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

end
