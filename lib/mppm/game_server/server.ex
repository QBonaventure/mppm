defmodule Mppm.GameServer.Server do
  require Logger
  import Ecto.Query
  use GenServer
  alias Mppm.ServerConfig

  @config Application.get_env(:mppm, Mppm.Trackmania)
  @msg_waiting_ports "Waiting for game server ports to open..."
  @max_start_attempts 20
  @start_timeout 12000



  def start(server_login) when is_binary(server_login) do
    GenServer.call(proc_name(server_login), :start, @start_timeout)
  end

  def stop(server_login) when is_binary(server_login) do
    GenServer.call(proc_name(server_login), :stop)
  end

  def restart(server_login) when is_binary(server_login) do
    GenServer.call(proc_name(server_login), :restart)
  end

  def get_next_game_mode_id(server_id) do
    Mppm.Repo.one(from r in Mppm.GameRules, select: r.mode_id, where: r.server_id == ^server_id)
  end


  ############################################
  ########### GenServer callbacks ############
  ############################################

  def child_spec(%ServerConfig{} = server_config) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[server_config], []]},
      restart: :transient,
      name: {:global, {:game_server, server_config.login}}
    }
  end

  def start_link([%ServerConfig{} = server_config], _opts \\ []) do
    GenServer.start_link(__MODULE__, server_config, name: {:global, {:game_server, server_config.login}})
  end


  def init(%ServerConfig{} = server_config) do
    Phoenix.PubSub.subscribe(Mppm.PubSub, "tracklist-status")
    Phoenix.PubSub.subscribe(Mppm.PubSub, "ruleset-status")

    state = %{
      current_track: nil,
      port: nil,
      os_pid: nil,
      exit_status: nil,
      latest_output: nil,
      listening_ports: nil,
      xmlrpc_port: nil,
      status: :stopped,
      config: server_config,
      rewrite_ruleset?: false,
      rewrite_config?: false,
      rewrite_tracklist?: false,
      reload_match_settings?: false,
      game_mode_id: nil
    }

    {:ok, state}
  end


  def handle_call(:start, _from, state) do
    case Mppm.ServersStatuses.get_start_flag(state.config.login) do
      :ok ->
        {_, state} = start_server(state)
        {:reply, {:ok, :starting}, %{state | status: :starting}}
      _ ->
        {:reply, {:ok, :not_startable}, state}
    end
  end

  def handle_call(:stop, _from, state) do
    case Mppm.ServersStatuses.get_stop_flag(state.config.login) do
      :ok ->
        {_, state} = stop_server(state)
        {:reply, {:ok, :stopping}, %{state | status: :stopping}}
      _ ->
      {:reply, {:ok, :not_stoppable}, state}
    end
  end

  def handle_call(:restart, _from, state) do
    {_, state} = stop_server(state)
    {_, state} = start_server(state)
    {:reply, state, state}
  end

  def handle_cast({:relink_orphan_process, {login, pid, xmlrpc_port} = ss}, state) do
    Mppm.Broker.Supervisor.child_spec(state.config, xmlrpc_port)
    |> Mppm.GameServer.Supervisor.start_child

    Mppm.ServersStatuses.update_server_status(login, :started)
    state = %{state |
      status: :started,
      xmlrpc_port: xmlrpc_port,
      listening_ports: %{xmlrpc: xmlrpc_port},
      port: nil,
      os_pid: pid,
      rewrite_ruleset?: false,
      rewrite_config?: false,
      rewrite_tracklist?: false,
      reload_match_settings?: false,
      game_mode_id: nil
    }

    {:noreply, state}
  end


  def handle_cast(:closing_port, state) do
    Mppm.ServersStatuses.update_server_status(state.config.login, :stopped)
    {:noreply, %{state | exit_status: :port_closed, status: :stopped}}
  end


  def handle_call(:pid, _, state) do
    {:reply, self(), state}
  end


  def handle_call(:xmlrpc_port, _, state) do
    case state.listening_ports do
      nil -> {:reply, nil, state}
      %{xmlrpc: port} -> {:reply, port, state}
    end
  end


  def handle_call(:status, _, state) do
    {:reply, %{state: state.status, port: state.port, os_pid: state.os_pid}, state}
  end


  def handle_call(:get_state, _, state) do
    {:reply, state, state}
  end


  def handle_call(:get_current_game_mode_id, _, state) do
    {:reply, state.game_mode_id, state}
  end



  def handle_info({:ruleset_change, server_login, _ruleset_or_tracklist}, state) do
    case server_login == state.config.login do
      true -> {:noreply, %{state | rewrite_ruleset?: true}}
      false -> {:noreply, state}
    end
  end


  def handle_info({:tracklist_update, server_login, ruleset_or_tracklist}, state) do
    case server_login == state.config.login do
      true ->
        Mppm.ServerConfig.create_tracklist(ruleset_or_tracklist)
        {:noreply, %{state | rewrite_tracklist?: true}}
      false -> {:noreply, state}
    end
  end


  def handle_info({:podium_start, _server_login}, state) do
    Mppm.ServerConfig
    |> Mppm.Repo.get(state.config.id)
    |> Mppm.Repo.preload(:ruleset)
    |> Mppm.ServerConfig.create_ruleset_file()
    {:noreply, state}
  end


  def handle_info({:podium_end, server_login}, state) do
    case state.config.login == server_login do
      true ->
        GenServer.cast({:global, {:broker_requester, server_login}}, :reload_match_settings)
        {:noreply, %{state | reload_match_settings?: false}}
      false ->
        {:noreply, state}
    end
  end


  def handle_info({:end_of_game, _server_login}, state) do
    {:noreply, %{state | game_mode_id: get_next_game_mode_id(state.config.id)}}
  end


  def handle_info({:start_of_match, server_login}, state) do
    if state.config.login == server_login do
      GenServer.cast({:global, {:broker_requester, server_login}}, :reload_match_settings)
    end
    {:noreply, state}
  end


  def handle_info({:current_game_mode, %Mppm.Type.GameMode{id: mode_id}}, state) do
    {:noreply, %{state | game_mode_id: mode_id}}
  end


  def handle_info(:stop, state) do
    stop_server(state)
    {:noreply, %{state | exit_status: :port_closed, status: :stopped}}
  end


  def handle_info({:DOWN, _ref, :port, port, :normal}, %{exit_status: :port_closed} = state) do
    Logger.info "Process successfully stopped through Port: #{inspect port}"

    {:noreply, state}
  end

  # Callback for info upon normally stopping a game server.
  def handle_info({:DOWN, _ref, :port, _port, :normal}, state) do
    {:noreply, %{state | status: :stopped}}
  end


  def handle_info({_port, {:data, text_line}}, state) do
    latest_output = text_line |> String.trim

    Logger.info "[#{state.config.login}] #{latest_output}"

    {:noreply, %{state | latest_output: latest_output}}
  end


  def handle_info({_port, {:exit_status, status}}, state) do
    Logger.info "External exit: :exit_status: #{Atom.to_string(status)}"
    {:noreply, %{state | exit_status: status}}
  end


  def handle_info(_unhandled_message, state), do:
    {:noreply, state}



  ############################################
  ############ Private functions #############
  ############################################

  defp broadcast(server_login, msg) do
    Phoenix.PubSub.broadcast(Mppm.PubSub, "server-status", msg)
  end

  defp proc_name(server_login), do:
    {:global, {:game_server, server_login}}

  defp get_command(%ServerConfig{login: filename, version: version}) do
    "#{Mppm.GameServer.DedicatedServer.executable_path(version)} /nologs /dedicated_cfg=#{filename}.txt /game_settings=MatchSettings/#{filename}.txt /nodaemon"
  end


  defp kill_server_process(pid) when is_integer(pid), do:
    System.cmd("kill", ["#{pid}"])


  defp get_listening_ports(pid, tries \\ 0)
  defp get_listening_ports(pid, tries) when is_integer(pid) and tries >= @max_start_attempts do
    kill_server_process(pid)
    {:error, :unknown_reason}
  end
  defp get_listening_ports(pid, tries) when is_integer(pid) do
    res =
      :os.cmd('ss -lpn | grep "pid=#{pid}" | awk {\'print$5\'} | cut -d: -f2')
      |> to_string
      |> String.split("\n", trim: true)
      |> Enum.map(fn p ->
          case String.at(p, 0) do
            "2" -> {:server, String.to_integer(p)}
            "3" -> {:p2p, String.to_integer(p)}
            "5" -> {:xmlrpc, String.to_integer(p)}
          end
        end)
      |> Map.new

    case res do
      %{xmlrpc: _xmlrpc, server: _server} = ports ->
        {:ok, ports}
      _ ->
        Logger.info @msg_waiting_ports
        Process.sleep(1000)
        get_listening_ports(pid, tries+1)
    end
  end


  defp start_server(state) do
    broadcast("server-status", {:starting, state.config.login})
    config = Mppm.Repo.get(Mppm.ServerConfig, state.config.id) |> Mppm.Repo.preload(:ruleset)
    ServerConfig.create_config_file(config)
    ServerConfig.create_ruleset_file(config)
    GenServer.call(Mppm.Tracklist, {:get_server_tracklist, config.login})
    |> Mppm.ServerConfig.create_tracklist()

    command = get_command(config)
    port = Port.open({:spawn, command}, [:binary, :exit_status])
    {:os_pid, os_pid} = Port.info(port, :os_pid)
    Port.monitor(port)

    state =
      case get_listening_ports(os_pid) do
        {:ok, listening_ports} ->
          {:ok, _child_pid} =
            Mppm.Broker.Supervisor.child_spec(state.config, listening_ports.xmlrpc)
            |> Mppm.GameServer.Supervisor.start_child()
          Mppm.ServersStatuses.update_server_status(state.config.login, :started)
          broadcast("server-status", {:started, state.config.login})
          %{
            state |
            config: config,
            status: :started,
            listening_ports: listening_ports,
            port: port,
            os_pid: os_pid,
            game_mode_id: get_next_game_mode_id(state.config.id)
          }
        {:error, _} ->
          Mppm.ServersStatuses.update_server_status(state.config.login, :failed)
          Logger.info "["<>state.config.login<>"] Server couldn't start"
            broadcast("server-status", {:start_failed, state.config.login})
          %{state | status: :stopped}
      end
    {:ok, state}
  end


  defp stop_server(state) do
    broadcast("server-status", {:stopping, state.config.login})
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

    Mppm.ServersStatuses.update_server_status(state.config.login, :stopped)
    Logger.info "["<>state.config.login<>"] Server has been stopped"

    broadcast("server-status", {:stopped, state.config.login})
    {:ok, %{state | os_pid: nil, listening_ports: nil, port: nil, status: :stopped}}
  end

end
