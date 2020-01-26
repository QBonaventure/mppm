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

    DynamicSupervisor.start_child(__MODULE__, mps_spec)
  end


end
