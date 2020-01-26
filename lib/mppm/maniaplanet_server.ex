defmodule Mppm.ManiaplanetServer do
  alias __MODULE__
  require Logger
  use GenServer
  alias Mppm.ServerConfig

  @root_path Application.get_env(:mppm, :mp_servers_root_path)

  def child_spec(%ServerConfig{} = server_config) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[server_config], []]},
      restart: :transient,
      name: {:global, {:mp_server, server_config.login}}
    }
  end

  # GENSERVER BEHAVIOUR IMPL

  def start_link([%ServerConfig{} = server_config], _opts \\ []) do
    GenServer.start_link(__MODULE__, server_config, name: {:global, {:mp_server, server_config.login}})
  end


  def init(%ServerConfig{} = server_config) do
    {:ok, port} = start_server(server_config)
    {:os_pid, os_pid} = Port.info(port, :os_pid)

    Process.sleep(5000)
    listening_ports = get_listening_ports(os_pid)

    state = %{
      port: port,
      controller_port: port,
      os_pid: os_pid,
      exit_status: nil,
      latest_output: nil,
      listening_ports: listening_ports,
      status: "running", config: server_config
    }

    {:ok, state}
  end



  # FUNCTIONS

  defp get_command(%ServerConfig{login: filename, title_pack: title_pack}) do
    "#{@root_path}/ManiaPlanetServer /title=#{title_pack} /dedicated_cfg=#{filename}.txt /game_settings=MatchSettings/#{filename}.txt /nodaemon"
  end


  def get_listening_ports(pid) when is_integer(pid) do
    res = :os.cmd('ss -lpn | grep "pid=#{pid}" | awk {\'print$5\'} | cut -d: -f2')
    |> to_string
    |> String.split("\n", trim: true)
    |> Enum.map(fn p ->
        case String.at(p, 0) do
          "2" -> {"server", p}
          "3" -> {"p2p", p}
          "5" -> {"xmlrpc", p}
        end
      end)
    |> Map.new

    case res do
      %{"xmlrpc" => _xmlrpc, "server" => _server} ->
        res
      _ ->
        Process.sleep(1000)
        get_listening_ports(pid)
    end
  end


  def start_server(%ServerConfig{} = server_config \\ []) do
    ServerConfig.create_config_file(server_config)
    ServerConfig.create_tracklist(server_config)
    command = get_command(server_config)
    port = Port.open({:spawn, command}, [:binary, :exit_status])
    Port.monitor(port)

    Phoenix.PubSub.broadcast(Mppm.PubSub, "server_status", :update)

    {:ok, port}
  end


  def stop_server(state) do
    {:os_pid, pid} = Port.info(state.port, :os_pid)
    System.cmd("kill", ["#{pid}"])
    Port.close(state.port)
    {:ok, %{state | port: nil, status: "stopped"}}
  end


  def list_servers() do
    servers = :global.registered_names()
    Enum.map(servers, fn server ->
      {:reply, GenServer.call({:global, server}, :status)}
    end)
  end


  def servers_status() do
    servers = :global.registered_names()
    Enum.reduce(servers, %{}, fn server, acc ->
      {server_type, server_name} = server
      server_status = GenServer.call({:global, server}, :status)
      Map.put(acc, server_name, Map.get(acc, server_name,[]) ++ ["#{server_type}": server_status])
   end)
  end




  ##########################
  #        Callbacks       #
  ##########################

  def handle_call(:status, _, state) do
    {:reply, %{state: state.status, port: state.port, os_pid: state.os_pid}, state}
  end


  def handle_info(:start, state) do
    {:ok, port} = start_server(state.config)

    ###### IMPLEMENT TRY AGAIN IF NO XMLRPC PORT YET
    listening_ports = get_listening_ports(state.os_pid)
    {:noreply, %{state | port: port, exit_status: nil, listening_ports: listening_ports, status: "running"}}
  end


  def handle_info(:stop, state) do
    stop_server(state)
    {:noreply, %{state | exit_status: :port_closed, status: "stopped"}}
  end


  def handle_info(:restart, state) do
    stop_server(state)
    {:ok, port} = start_server(state.config)
    {:noreply, %{state | port: port, exit_status: nil, status: "running"}}
  end


  def handle_info({_port, {:data, text_line}}, state) do
    latest_output = text_line |> String.trim

    Logger.info "#{latest_output}"

    {:noreply, %{state | latest_output: latest_output}}
  end


  def handle_info({_port, {:exit_status, status}}, state) do
    Logger.info "External exit: :exit_status: #{status}"

    {:noreply, %{state | exit_status: status}}
  end

  # def handle_info({:DOWN, _ref, :port, port, :normal}, %{exit_status: 137} = state) do
  #   Logger.info "Handled :DOWN message from port: #{inspect port}"
  #
  #   start_server(state.config)
  #   {:noreply, state}
  # end


  # def handle_info({:DOWN, _ref, :port, port, :normal}, %{exit_status: :port_closed} = state) do
  #   Logger.info "Process successfully stopped through Port: #{inspect port}"
  #
  #   {:noreply, state}
  # end


  # def handle_info(msg, state) do
  #   Logger.info "Unhandled message: #{inspect msg}"
  #   {:noreply, state}
  # end


  def hh do
    %Mppm.ServerConfig{
      admin_pass: "eeM013xUvJ-U",
      comment: nil,
      login: "ftc_ps_3",
      max_players: 32,
      name: "FTC PS3",
      password: "6eWhmzPkQbGFS5KXkCvl",
      player_pwd: nil,
      spec_pwd: nil,
      superadmin_pass: "8l-W2DiFYUqj",
      title_pack: "TMStadium@nadeo",
      user_pass: "H5Cy11FrJ1dB"
    }
  end

end
