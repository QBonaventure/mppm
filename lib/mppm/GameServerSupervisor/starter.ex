defmodule Mppm.GameServerSupervisor.Starter do
  use GenServer
  alias Mppm.{ServerConfigStore,ManiaplanetServerSupervisor}
  alias __MODULE__

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
      {:ok, mp_server_pid} = ManiaplanetServerSupervisor.start_server_supervisor(server_config)
    end)
    {:stop, :normal, %{}}
  end



  ##############################################
  ### Functions to retrieve zombie processes ###
  ##############################################


  @trackmania 'TrackmaniaServer'

  def relink_lost_processes() do
    {:ok, zombie_processes} = get_zombie_processes()

    Enum.each(zombie_processes, fn {pid, port} ->
      IO.inspect port
    end)
  end


  def get_zombie_processes() do
    pids_list = get_pids_list()

    result =
      case pids_list do
        [] -> "TODO"
        pids ->
          Enum.map(pids, fn pid -> get_processes_xmlrpc_ports(pid) end)
      end

    {:ok, result}
  end

  def get_pids_list() do
    :os.cmd('ps -aux | grep ' ++ @trackmania ++ ' | awk \'{print $2}\'')
    |> List.to_string()
    |> String.split()
    |> Enum.drop(-1)
    |> Enum.map(fn value -> String.to_charlist(value) end)
  end

  defp get_processes_xmlrpc_ports(pid) do
    :os.cmd('netstat -antp | grep ' ++ pid ++ '/ | awk \'{print $4}\'')
    |> List.to_string()
    |> String.split(~r{\n}, trim: true)
    |> Enum.drop(2)
    |> Enum.map(& case &1 do
          "127.0.0.1:"<>port -> {pid, port}
          _ -> nil
        end)
    |> List.flatten
    |> Enum.filter(& !is_nil(&1))
    |> List.first

  end


  def gzp() do
    Starter.get_zombie_processes()
  end

end
