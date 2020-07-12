defmodule Mppm.ManiaplanetServerSupervisor do
  use DynamicSupervisor
  alias DynamicSupervisorWithRegistry.Worker
  alias Mppm.ManiaplanetServer


  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end


  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(mps_spec) do
    DynamicSupervisor.start_child(__MODULE__, mps_spec)
  end


  def start_mp_server(%Mppm.ServerConfig{} = serv_conf) do
    {:ok, mp_server_state} = GenServer.call({:global, {:mp_server, serv_conf.login}}, :start, 10000)

    GenServer.call({:global, {:mp_controller, serv_conf.login}}, {:start, mp_server_state}, 10000)
  end


  def stop_mp_server(server_id) do
    {:ok, mpc_pid} = GenServer.call({:global, {:mp_controller, server_id}}, :stop)

    {:ok, mps_pid} = GenServer.call({:global, {:mp_server, server_id}}, :stop)

    {:ok}
  end


  def handle_info(msg, state) do
    {:noreply, state}
  end


end
