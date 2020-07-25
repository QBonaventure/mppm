defmodule Mppm.ManiaplanetServer do
  require Logger
  use GenServer
  alias Mppm.{ServerConfig,Statuses}

  @root_path Application.get_env(:mppm, :mp_servers_root_path)
  @msg_waiting_ports "Waiting for game server ports to open..."

  ###################################
  ##### START FUNCTIONS #############
  ###################################

  defp get_command(%ServerConfig{login: filename}) do
    "#{@root_path}TrackmaniaServer /nologs /dedicated_cfg=#{filename}.txt /game_settings=MatchSettings/#{filename}.txt /nodaemon"
  end


  def get_listening_ports(pid, tries \\ 0) when is_integer(pid) do
    res = :os.cmd('ss -lpn | grep "pid=#{pid}" | awk {\'print$5\'} | cut -d: -f2')
    |> to_string
    |> String.split("\n", trim: true)
    |> Enum.map(fn p ->
        case String.at(p, 0) do
          "2" -> {"server", String.to_integer(p)}
          "3" -> {"p2p", String.to_integer(p)}
          "5" -> {"xmlrpc", String.to_integer(p)}
        end
      end)
    |> Map.new

    case res do
      %{"xmlrpc" => _xmlrpc, "server" => _server} ->
        res
      _ ->
        IO.puts @msg_waiting_ports
        Process.sleep(1000)
        get_listening_ports(pid, tries+1)
    end
  end

  def update_status(login, status) do
    Statuses.update_server(login, status)
    Phoenix.PubSub.broadcast(Mppm.PubSub, "server_status", :update)
    {:ok, status}
  end

  def start_server(state) do
    ServerConfig.create_config_file(state.config)
    ServerConfig.create_tracklist(state.config)

    command = get_command(state.config)
    port = Port.open({:spawn, command}, [:binary, :exit_status])
    {:os_pid, os_pid} = Port.info(port, :os_pid)
    Port.monitor(port)

    listening_ports = get_listening_ports(os_pid)

    Mppm.Broker.child_spec(state.config, listening_ports["xmlrpc"])
    |> Mppm.ManiaplanetServerSupervisor.start_child

    state = %{state | status: "started", listening_ports: listening_ports, port: port}

    {:ok, state}
  end




  ###################################
  ##### STOP FUNCTIONS ##############
  ###################################

  def stop_server(state) do
    GenServer.call({:global, {:mp_broker, state.config.login}}, :stop)
    IO.inspect Port.info(state.port, :os_pid)
    {:os_pid, pid} = Port.info(state.port, :os_pid)
    Port.close(state.port)
    System.cmd("kill", ["#{pid}"])

    update_status(state.config.login, "stopped")

    {:ok, %{state | port: nil, status: "stopped"}}
  end

  def handle_cast(:closing_port, state) do
    {:noreply, %{state | exit_status: :port_closed, status: "stopped"}}
  end




  ###################################
  ##### OTHER FUNCTIONS #############
  ###################################



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


  def handle_cast({:incoming_game_message, message}, state) do
    IO.puts "-----------------------------------------------"
    IO.inspect message
    {:noreply, state}
  end



  def handle_call(:start, _, state) do
    update_status(state.config.login, "starting")
    {:ok, new_state} = start_server(state)
    update_status(state.config.login, new_state.status)

    {:reply, {:ok, new_state}, new_state}
  end

  def handle_call(:stop, _, state) do
    stop_server(state)
    {:reply, {:ok, self()}, state}
  end

  def handle_call(:pid, _, state) do
    {:reply, self(), state}
  end


  def handle_call(:xmlrpc_port, _, state) do
    case state.listening_ports do
      nil -> {:reply, nil, state}
      %{"xmlrpc" => port} -> {:reply, port, state}
    end
  end


  def handle_call(:status, _, state) do
    {:reply, %{state: state.status, port: state.port, os_pid: state.os_pid}, state}
  end


  def handle_call(:get_state, _, state) do
    {:reply, state, state}
  end


  def handle_info(:stop, state) do
    stop_server(state)
    {:noreply, %{state | exit_status: :port_closed, status: "stopped"}}
  end


  def handle_info({:DOWN, _ref, :port, port, :normal}, %{exit_status: :port_closed} = state) do
    Logger.info "Process successfully stopped through Port: #{inspect port}"

    {:noreply, state}
  end

  # Callback for info upon normally stopping a game server.
  def handle_info({:DOWN, _ref, :port, port, :normal}, state) do
    {:noreply, %{state | status: "stopped"}}
  end

  def handle_info({_port, {:data, text_line}}, state) do
    latest_output = text_line |> String.trim

    Logger.info "[#{state.config.login}] #{latest_output}"

    {:noreply, %{state | latest_output: latest_output}}
  end


  def handle_info({_port, {:exit_status, status}}, state) do
    Logger.info "External exit: :exit_status: #{status}"

    {:noreply, %{state | exit_status: status}}
  end




  def child_spec(%ServerConfig{} = server_config) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[server_config], []]},
      restart: :transient,
      name: {:global, {:mp_server, server_config.login}}
    }
  end

  def start_link([%ServerConfig{} = server_config], _opts \\ []) do
    GenServer.start_link(__MODULE__, server_config, name: {:global, {:mp_server, server_config.login}})
  end


  def init(%ServerConfig{} = server_config) do
    state = %{
      port: nil,
      controller_port: nil,
      os_pid: nil,
      exit_status: nil,
      latest_output: nil,
      listening_ports: nil,
      xmlrpc_port: nil,
      status: "stopped",
      config: server_config
    }

    {:ok, state}
  end


end
