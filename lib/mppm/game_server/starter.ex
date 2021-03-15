defmodule Mppm.GameServer.Starter do
  use GenServer


  def start_link do
    GenServer.start_link(__MODULE__, nil)
  end

  def init(_) do
    send(self(), :start_children)
    {:ok, %{last_run_at: :calendar.local_time()}}
  end

  def handle_info(:start_children, _) do
    Mppm.Repo.all(Mppm.GameServer.Server)
    |> Enum.each(fn server ->
      {:ok, _server_pid} = Mppm.GameServer.Supervisor.start_server_supervisor(server)
    end)
    relink_lost_processes()

    {:stop, :normal, %{}}
  end



  ##############################################
  ### Functions to retrieve zombie processes ###
  ##############################################
#TODO

  @trackmania 'TrackmaniaServer'

  def relink_lost_processes() do
    {:ok, zombie_processes} = get_zombie_processes()
    Enum.each(zombie_processes, fn {login, _pid, _port} = tuple ->
      GenServer.cast({:global, {:game_server, login}}, {:relink_orphan_process, tuple})
    end)
  end


  def get_zombie_processes() do
    pids_list = get_pids_list()
    result =
      case pids_list do
        [] -> []
        pids ->
          Enum.map(pids, & get_processes_xmlrpc_ports(&1))
      end

    {:ok, result}
  end


  defp to_pid_login_tuple([pid, login]) do
    {pid, ""} = Integer.parse(pid)
    {pid, login}
  end
  defp to_pid_login_tuple(_), do: nil

  def get_pids_list() do
    :os.cmd('ps -aux | grep ' ++ @trackmania)
    |> List.to_string()
    |> String.split("\n")
    |> Enum.map(&
      Regex.scan(~r|[a-z]+\s+([0-9]+)\s.*cfg=.*/([0-9a-zA-Z_].*)\.txt|, &1, capture: :all_but_first)
      |> List.flatten
      |> to_pid_login_tuple
      )
    |> Enum.filter(& !is_nil(&1))
  end


  defp get_processes_xmlrpc_ports({pid, login}) do
    {^pid, port} =
      :os.cmd('netstat -antp | grep #{pid}/ | awk \'{print $4}\'')
      |> List.to_string()
      |> String.split(~r{\n}, trim: true)
      |> Enum.drop(2)
      |> Enum.map(& case &1 do
            "127.0.0.1:"<>port ->
              {port, _} = Integer.parse(port)
              {pid, port}
            _ -> nil
          end)
      |> List.flatten
      |> Enum.filter(& !is_nil(&1))
      |> List.first

    {login, pid, port}
  end

  def get_zombie_process_info() do
    :os.cmd('ps -aux | grep '++@trackmania)
    |> List.to_string
    |> String.split(~r{\n}, trim: true)
  end


end
