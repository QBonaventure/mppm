defmodule Mppm.ManiaplanetServerSupervisor do
  use DynamicSupervisor
  alias Mppm.{ServerConfig,ManiaplanetServer}
  alias __MODULE__


  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end


  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(%{id: Mppm.ManiaplanetServer} = mps_spec) do
    {:ok, _child_pid} = DynamicSupervisor.start_child(__MODULE__, mps_spec)
  end

  def start_child(%{id: Mppm.Broker.Supervisor} = broker_spec) do
    {:ok, _child_pid} = DynamicSupervisor.start_child(__MODULE__, broker_spec)
  end

  def start_server_supervisor(%ServerConfig{} = server_config) do
    {:ok, mp_server_pid} =
      ManiaplanetServer.child_spec(server_config)
      |> ManiaplanetServerSupervisor.start_child

    :ok = Mppm.Statuses.add_new_server(server_config.login)

    {:ok, mp_server_pid}
  end



  def start_mp_server(%ServerConfig{} = serv_conf) do
    case GenServer.call({:global, {:mp_server, serv_conf.login}}, :start, 10000) do
      {:ok, _mp_server_state} ->
        "TO REMOVE?"
        # GenServer.call({:global, {:mp_broker, serv_conf.login}}, {:start, mp_server_state}, 10000)
        # GenServer.call({:global, {:mp_controller, serv_conf.login}}, {:start, mp_server_state}, 10000)
      _ -> "TO DO"
    end
  end


  def stop_mp_server(server_id) do
    # {:ok, _mpc_pid} = GenServer.call({:global, {:mp_controller, server_id}}, :stop)

    {:ok, _mps_pid} = GenServer.call({:global, {:mp_server, server_id}}, :stop)

    {:ok}
  end


  def handle_info(msg, state) do
    {:noreply, state}
  end


end
