defmodule Mppm.ManiaplanetServer do
  require Logger
  use GenServer
  alias Mppm.{ServerConfig,Statuses}

  @root_path Application.get_env(:mppm, :mp_servers_root_path)
  @config Application.get_env(:mppm, Mppm.Trackmania)
  @msg_waiting_ports "Waiting for game server ports to open..."
  @max_start_attempts 20

  ###################################
  ##### START FUNCTIONS #############
  ###################################

  defp get_command(%ServerConfig{login: filename}) do
    "#{@root_path}TrackmaniaServer /nologs /dedicated_cfg=#{filename}.txt /game_settings=MatchSettings/#{filename}.txt /nodaemon"
  end




  def get_listening_ports(pid, tries) when is_integer(pid) and tries >= @max_start_attempts do
    kill_server_process(pid)
    {:error, :unknown_reason}
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
        {:ok, res}
      _ ->
        Logger.info @msg_waiting_ports
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
    server_config = Mppm.Repo.get(Mppm.ServerConfig, state.config.id)
    ServerConfig.create_config_file(server_config)
    ServerConfig.create_ruleset_file(server_config)
    ServerConfig.create_tracklist(state.config)

    command = get_command(state.config)
    port = Port.open({:spawn, command}, [:binary, :exit_status])
    {:os_pid, os_pid} = Port.info(port, :os_pid)
    Port.monitor(port)

    state =
      case get_listening_ports(os_pid) do
        {:ok, listening_ports} ->
          {:ok, _child_pid} =
            Mppm.Broker.Supervisor.child_spec(state.config, listening_ports["xmlrpc"])
            |> Mppm.ManiaplanetServerSupervisor.start_child()

          Phoenix.PubSub.broadcast(Mppm.PubSub, "server_status", :update)
          %{state | status: "started", listening_ports: listening_ports, port: port}
        {:error, _} ->
          Logger.info "Server '"<>state.config.login<>"' couldn't start"
          %{state | status: "stopped"}
      end

    {:ok, state}
  end


  def handle_cast({:relink_orphan_process, {login, pid, xmlrpc_port}}, state) do
    server_config = Mppm.Repo.get_by(Mppm.ServerConfig, login: login)

    Mppm.Broker.Supervisor.child_spec(state.config, xmlrpc_port)
    |> Mppm.ManiaplanetServerSupervisor.start_child

    update_status(login, "started")
    state = %{state |
      status: "started",
      xmlrpc_port: xmlrpc_port,
      listening_ports: %{"xmlrpc" => xmlrpc_port},
      port: nil,
      os_pid: pid
    }

    {:noreply, state}
  end



  ###################################
  ##### STOP FUNCTIONS ##############
  ###################################

  def stop_server(state) do
    Supervisor.stop({:global, {:broker_supervisor, state.config.login}})
    pid =
      case state.port do
        nil ->
          state.os_pid
        port ->
          {:os_pid, pid} = Port.info(port, :os_pid)
          Port.close(port)
          pid
      end
    kill_server_process(pid)

    update_status(state.config.login, "stopped")

    Logger.info "Server '"<>state.config.login<>"' has been stopped"

    {:ok, %{state | port: nil, status: "stopped"}}
  end

  def kill_server_process(pid) when is_integer(pid), do: System.cmd("kill", ["#{pid}"])

  def handle_cast(:closing_port, state) do
    update_status(state.config.login, "stopped")
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

  @game_server_download_path "/tmp/tm_server_latest.zip"

  def update_game_server(root_path) do
    Logger.info "Installing lastest Trackmania game server"
    Logger.info "Downloading files..."
    {:ok, %HTTPoison.Response{body: body}} = HTTPoison.get(Keyword.get(@config, :download_link))
    Logger.info "Installing game server files..."
    :zip.unzip(body, [{:cwd, ~c'#{root_path}'}])
    Logger.info "Game server installed/updated"
    :ok
  end




  ##########################
  #        Callbacks       #
  ##########################

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

  def handle_call(:get_current_track, _, state) do
    {:reply, state.current_track, state}
  end

  def handle_call(:status, _, state) do
    {:reply, %{state: state.status, port: state.port, os_pid: state.os_pid}, state}
  end


  def handle_call(:get_state, _, state) do
    {:reply, state, state}
  end


  def handle_info({:current_map_info, %{"UId" => map_uid}}, state), do:
    {:noreply, %{state | current_track: Mppm.Repo.get_by(Mppm.Track, track_uid: map_uid)}}
  def handle_info({:beginmap, %{"UId" => map_uid}}, state), do:
    {:noreply, %{state | current_track: Mppm.Repo.get_by(Mppm.Track, track_uid: map_uid)}}
  def handle_info({:endmatch}, state), do: {:noreply, state}
  def handle_info({:endmap}, state), do: {:noreply, state}
  def handle_info({:beginmatch}, state), do: {:noreply, state}


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


  def handle_info(_unhandled_message, state), do: {:noreply, state}




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
    Phoenix.PubSub.subscribe(Mppm.PubSub, "server_status_"<>server_config.login)
    state = %{
      current_track: nil,
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
