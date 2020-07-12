defmodule Mppm.ManiaplanetServerSupervisorStarter do
  use GenServer
  alias Mppm.ServerConfigStore

  @moduledoc """
  Worker starting stored Mppm.ManiaplanetServerSupervisor children
  on application start.
  """

  def start_link do
    GenServer.start_link(__MODULE__, nil)
  end

  def init(_) do
    send(self(), :start_children)
    {:ok, %{last_run_at: :calendar.local_time()}}
  end

  def handle_info(:start_children, _) do
    ServerConfigStore.all
    |> Enum.map(fn(server_config) ->
      {:ok, mp_server_pid} =
        Mppm.ManiaplanetServer.child_spec(server_config)
        |> Mppm.ManiaplanetServerSupervisor.start_child

      mp_server_state = :sys.get_state(mp_server_pid)

      ### Disabled controller management for now.
      Mppm.Controller.child_spec(mp_server_state)
      |> Mppm.ManiaplanetServerSupervisor.start_child
    end)
    {:stop, :normal, %{}}
  end
end
