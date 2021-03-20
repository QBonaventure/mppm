defmodule Mppm.SystemWatcher do
  use GenServer


  @cmd "top -bn1 -d 1 -p $(pgrep -d',' Track)"
  @cmd2 ~w(| grep Track)


  def handle_info({port, {:data, data}}, state) do
    data = parse(data)
    Mppm.PubSub.broadcast("system-stats", {:servers_stats, data})
    {:noreply, data}
  end

  def handle_info({port, {:exit_status, 1}}, state) do
    Mppm.PubSub.broadcast("system-stats", {:servers_stats, []})
    {:noreply, []}
  end

  def handle_info({port, {:exit_status, 0}}, state) do
    {:noreply, state}
  end

  def handle_info(:fetch_data, state) do
    port = Port.open({:spawn, @cmd}, [:binary, :exit_status])
    Process.send_after(__MODULE__, :fetch_data, 2000)
    {:noreply, state}
  end

def test() do
data = System.cmd("top -bn1 -d 2 -p $(pgrep -d',' Track)", []) |> parse
end

  def parse(data) do
    data =
      data
      |> String.trim()
      |> String.split("\n")
    index = Enum.find_index(data, & &1 == "") + 2
    {_, data} = Enum.split(data, index)
    servers_info =
      Mppm.GameServer.Server.list_of_running()
      |> Enum.map(& {&1.pid, &1.login})
      |> Map.new
    data
    |> Enum.map(fn line ->
      server_data =
        line
        |> String.trim()
        |> String.split()
        |> extract()
      Map.put(server_data, :login, Map.get(servers_info, server_data.pid))
    end)
    |> Enum.sort_by(& &1.login)
  end

  defp extract([pid, _user, _pr, _ni, _virt, _res, _shr, _s, cpu, mem, _time, _cmd]) do
    %{pid: String.to_integer(pid), cpu: String.to_float(cpu), memory: String.to_float(mem) }
  end


  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def init(_) do
    port = Port.open({:spawn, @cmd}, [:binary, :exit_status])
    Process.send_after(__MODULE__, :fetch_data, 2000)
    {:ok, %{}}
  end


end
