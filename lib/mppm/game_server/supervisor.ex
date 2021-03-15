defmodule Mppm.GameServer.Supervisor do
  alias Mppm.ServerConfig
  alias Mppm.GameServer.Server


  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(%{id: Mppm.GameServer.Server} = server_spec) do
    {:ok, _child_pid} = DynamicSupervisor.start_child(__MODULE__, server_spec)
  end

  def start_child(%{id: Mppm.Broker.Supervisor} = broker_spec) do
    {:ok, _child_pid} = DynamicSupervisor.start_child(__MODULE__, broker_spec)
  end


  @doc """
  Starts a game server GenServer upon creation or app start.

  Returns: {:ok, pid()}
  """
  @spec start_server_supervisor(Mppm.GameServer.Server.t()) :: {:ok, pid()}
  def start_server_supervisor(%Server{} = server) do
    {:ok, mp_server_pid} =
      Mppm.GameServer.Server.child_spec(server)
      |> Mppm.GameServer.Supervisor.start_child
    {:ok, mp_server_pid}
  end


  @doc """
  Terminates a game server GenServer upon deletion.

  Returns: :ok on successs, {:error, :not_found}
  """
  @spec stop_server_supervisor(GenServer.name()) :: :ok | {:error, :not_found}
  def stop_server_supervisor({:global, {:game_server, _login}} = proc_name) do
    pid = GenServer.whereis(proc_name)
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

end
