defmodule Mppm.ManiaplanetServerSupervisor do
  use DynamicSupervisor
  alias DynamicSupervisorWithRegistry.Worker
  alias Mppm.ManiaplanetServer

  def start_link(_arg),
    do: DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_mp_server(%Mppm.ServerConfig{} = serv_conf) do
    mps_spec = Mppm.ManiaplanetServer.child_spec(serv_conf)
    {:ok, pid} = DynamicSupervisor.start_child(__MODULE__, mps_spec)

    server_state = :sys.get_state(pid)



    mpc_spec = case serv_conf.controller do
      "maniacontrol" -> Mppm.Controller.Maniacontrol.child_spec(server_state)
      "pyplanet" -> Mppm.Controller.Pyplanet.child_spec(server_state)
    end
    {:ok, _} = DynamicSupervisor.start_child(__MODULE__, mpc_spec)
  end

  def handle_info(msg, state) do
    IO.inspect msg
    IO.inspect state
    {:noreply, state}
  end


end
