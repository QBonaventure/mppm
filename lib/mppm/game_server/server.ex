defmodule Mppm.GameServer.Server do
  require Logger
  use Ecto.Schema
  use GenServer
  import Ecto.Changeset
  import Ecto.Query
  import Mppm.PubSub, only: [broadcast: 2]
  alias Mppm.ServerConfig
  alias __MODULE__

  @msg_waiting_ports "Waiting for game server ports to open..."
  @max_start_attempts 20
  @start_timeout 12000

  schema "servers" do
    field :login, :string
    field :password, :string
    field :name, :string
    field :comment, :string
    field :exe_version, :integer
    has_one :config, Mppm.ServerConfig, foreign_key: :server_id, on_replace: :update
    has_one :ruleset, Mppm.GameRules, foreign_key: :server_id, on_replace: :update
    has_one :tracklist, Mppm.Tracklist, foreign_key: :server_id, on_replace: :update
  end

  @type t() :: %Mppm.GameServer.Server{
    login: server_login(),
    password: String.t(),
    name: String.t(),
    comment: String.t(),
    exe_version: integer(),
  }
  @type server_login() :: String.t()
  @type status() :: atom()


  @required [:login, :password, :name, :exe_version, :config, :ruleset]
  def changeset(%__MODULE__{} = server, data \\ %{}) do
    data =
      case is_nil(server.id) do
        false ->
          data
        true ->
          data
          |> Map.put_new("ruleset", %{"mode_id" => 1})
          |> Map.put_new("tracklist", %{"tracks" => Mppm.Track.get_random_tracks(1)})
      end

    server
    |> cast(data, [:login, :password, :name, :comment, :exe_version])
    |> cast_assoc(:config, with: &Mppm.ServerConfig.changeset/2)
    |> cast_assoc(:ruleset, with: &Mppm.GameRules.changeset/2)
    |> cast_assoc(:tracklist, with: &Mppm.Tracklist.changeset/2)
    |> validate_required(@required)
    |> unique_constraint(:login, name: :uk_servers_login)
  end


  @doc """
  Starts a game server.
  """
  @spec start(server_login()) :: {:ok, :started} | {:none, status()}
  def start(server_login) when is_binary(server_login) do
    case GenServer.call(proc_name(server_login), :start_lock) do
      {:ok, :starting} ->
        broadcast("server-status", {:starting, server_login})
        {:ok, server} = GenServer.call(proc_name(server_login), :start, @start_timeout)
        broadcast("server-status", {server.status, server_login})
        {:ok, server.status}
      {:ok, status} ->
        {:none, status}
    end
  end


  @doc """
  Stops a game server.
  """
  @spec stop(server_login()) :: {:ok, :stopped} | {:none, status()}
  def stop(server_login) when is_binary(server_login) do
    case GenServer.call(proc_name(server_login), :stop_lock) do
      {:ok, :stopping} ->
        broadcast("server-status", {:stopping, server_login})
        {:ok, server} = GenServer.call(proc_name(server_login), :stop)
        broadcast("server-status", {server.status, server_login})
        {:ok, :stopped}
      {:ok, status} ->
        {:none, status}
    end
  end


  def restart(server_login) when is_binary(server_login) do
    stop(server_login)
    start(server_login)
  end

  def get_server(server_login) do
    {:ok, _server} = GenServer.call(proc_name(server_login), :get_server)
  end


  def server_status(server_login),
    do: GenServer.call(proc_name(server_login), :status, 1000)

  def server_id(server_login),
    do: Mppm.Repo.one(from s in Mppm.GameServer.Server, select: s.id, where: s.login == ^server_login)


  def update(%Ecto.Changeset{} = changeset) do
    case Mppm.Repo.update(changeset) do
      {:ok, new_server} ->
        Mppm.GameRules.propagate_ruleset_changes(changeset)
        GenServer.call(proc_name(changeset.data.login), {:update, new_server})
        {:ok, new_server}
      {:error, changeset} ->
        {:error, changeset}
    end
  end


  @doc """
  Updates the executable version a game server is running on.

  It does require a server restart for the change to be effective.

  Returns: {:ok, Mppm.GameServer.Server.t()} on success,
  {:error, Ecto.Changeset.t()} otherwise.
  """
  @spec change_version(Mppm.GameServer.Server.t(), Mppm.GameServer.DedicatedServer.t()) :: {:ok, Mppm.GameServer.Server.t()} | {:error, Ecto.Changeset.t()}
  def change_version(%__MODULE__{} = server, %Mppm.GameServer.DedicatedServer{} = exe_version) do
    changeset = changeset(server, %{"exe_version" => exe_version.version})
    case Mppm.Repo.update(changeset) do
      {:ok, new_server} ->
        GenServer.call(proc_name(server.login), {:update, new_server})
        {:ok, new_server}
      {:error, changeset} ->
        {:error, changeset}
    end
  end


  def get_next_game_mode_id(server_id) do
    Mppm.Repo.one(from r in Mppm.GameRules, select: r.mode_id, where: r.server_id == ^server_id)
  end


  def ids_list() do
    Mppm.Repo.all(from s in __MODULE__, select: s.id, order_by: s.id)
  end



  def list_of_running() do
    DynamicSupervisor.which_children(Mppm.GameServer.Supervisor)
    |> Enum.map(fn {_id, pid, _type, [_module]} ->
      case :sys.get_state(pid) do
        %{server: %Server{login: login}, os_pid: os_pid, status: status} ->
          %{login: login, status: status, pid: os_pid}
        _ ->
          %{}
      end
    end)
    |> Enum.reject(& &1 == %{})
    |> Enum.reject(& Map.get(&1, :status, :stopped) == :stopped)
  end


  @doc """
  Creates a game server and starts the supervisor
  """
  @spec create_new_server(Ecto.Changeset.t()) :: {:ok, Server.t()} | {:error, {:insert_failed, Ecto.Changeset.t()}}
  def create_new_server(%Ecto.Changeset{} = server_changeset) do
    with {:ok, server} <- Mppm.Repo.insert(server_changeset)
    do
      broadcast("server-status", {:created, server})
      {:ok, _pid} = Mppm.GameServer.Supervisor.start_server_supervisor(server)
      {:ok, server}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, {:insert_fail, changeset}}
    end
  end


  @doc """
  Deletes the game server and stops the GenServer
  """
  @spec delete_game_server(t()) :: {:ok, t()}
  def delete_game_server(%__MODULE__{} = server) do
    Mppm.GameServer.Supervisor.stop_server_supervisor(proc_name(server.login))
    {:ok, server} = Mppm.Repo.delete(server)
    broadcast("server-status", {:deleted, server})
    {:ok, server}
  end


  ##############################################################################
  ############################ GenServer Callbacks #############################
  ##############################################################################

  def child_spec(%__MODULE__{} = server) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[server], []]},
      restart: :transient,
      name: proc_name(server.login)
    }
  end

  def start_link([%__MODULE__{} = server], _opts \\ []) do
    GenServer.start_link(__MODULE__, server, name: proc_name(server.login))
  end


  def init(%__MODULE__{config: %Ecto.Association.NotLoaded{}} = server),
    do: init(Mppm.Repo.preload(server, :config))
  def init(%__MODULE__{ruleset: %Ecto.Association.NotLoaded{}} = server),
    do: init(Mppm.Repo.preload(server, :ruleset))
  def init(%__MODULE__{} = server) do
    Phoenix.PubSub.subscribe(Mppm.PubSub, "tracklist-status")
    Phoenix.PubSub.subscribe(Mppm.PubSub, "ruleset-status")

    state = %{
      server: server,
      current_track: nil,
      port: nil,
      os_pid: nil,
      exit_status: nil,
      latest_output: nil,
      listening_ports: nil,
      status: :stopped,
      game_mode_id: nil
    }

    {:ok, state}
  end


  def handle_call(:start_lock, _from, %{status: :stopped} = state) do
    {:reply, {:ok, :starting}, %{state | status: :starting}}
  end
  def handle_call(:start_lock, _from, state),
    do: {:reply, {:ok, state.status}, state}


  def handle_call(:stop_lock, _from, %{status: :started} = state) do
    {:reply, {:ok, :stopping}, %{state | status: :stopping}}
  end
  def handle_call(:stop_lock, _from, state),
    do: {:reply, {:ok, state.status}, state}


  def handle_call(:start, _from, state) do
    {:ok, _filename} = ServerConfig.create_config_file(state.server)
    {:ok, _filename} = Mppm.GameRules.create_ruleset_file(state.server)
    {:ok, _filename} = Mppm.Tracklist.create_tracklist(state.server)

    command = get_command(state.server)
    port = Port.open({:spawn, command}, [:binary, :exit_status])
    {:os_pid, os_pid} = Port.info(port, :os_pid)
    Port.monitor(port)

    state =
      case get_listening_ports(os_pid) do
        {:ok, listening_ports} ->
          {:ok, _child_pid} =
            Mppm.Broker.Supervisor.child_spec(state.server, listening_ports.xmlrpc)
            |> Mppm.GameServer.Supervisor.start_child()
          Process.sleep(2000)
          {:ok, _child_pid} =
            Mppm.GameUI.GameUISupervisor.child_spec(state.server.login)
            |> Mppm.GameServer.Supervisor.start_child()
          %{
            state |
            status: :started,
            listening_ports: listening_ports,
            port: port,
            os_pid: os_pid,
            game_mode_id: get_next_game_mode_id(state.server.id)
          }
        {:error, _} ->
          Logger.info "["<>state.server.login<>"] Server couldn't start"
          %{state | status: :stopped}
      end
    {:reply, {:ok, state}, state}
  end

  def handle_call(:stop, _from, state) do
    :ok = Supervisor.stop({:global, {:game_ui_supervisor, state.server.login}})
    :ok = Supervisor.stop({:global, {:broker_supervisor, state.server.login}})
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
    Logger.info "["<>state.server.login<>"] Server has been stopped"

    state =  %{state | os_pid: nil, listening_ports: nil, port: nil, status: :stopped}

    {:reply, {:ok, state}, state}
  end


  def handle_call({:update, new_server}, _from, state) do
    broadcast("server-status", {:updated, new_server})
    {:reply, {:ok, new_server}, %{state | server: new_server}}
  end


  def handle_call(:get_server, _from, state),
    do: {:reply, {:ok, state.server}, state}

  def handle_call(:id, _from, state),
    do: {:reply, state.server.id, state}


  def handle_call(:xmlrpc_port, _, state) do
    case state.listening_ports do
      nil -> {:reply, nil, state}
      %{xmlrpc: port} -> {:reply, port, state}
    end
  end


  def handle_call(:status, _, state) do
    {:reply, %{status: state.status, port: state.port, os_pid: state.os_pid}, state}
  end


  def handle_call(:get_state, _, state) do
    {:reply, state, state}
  end


  def handle_call(:get_current_game_mode_id, _, state) do
    {:reply, state.game_mode_id, state}
  end


  def handle_cast({:relink_orphan_process, {_login, pid, xmlrpc_port}}, state) do
    Mppm.Broker.Supervisor.child_spec(state.server, xmlrpc_port)
    |> Mppm.GameServer.Supervisor.start_child
    Mppm.GameUI.GameUISupervisor.child_spec(state.server.login)
    |> Mppm.GameServer.Supervisor.start_child()
    state = %{state |
      status: :started,
      listening_ports: %{xmlrpc: xmlrpc_port},
      port: nil,
      os_pid: pid,
      game_mode_id: nil
    }

    broadcast("server-status", {:started, state.server.login})

    {:noreply, state}
  end


  def handle_info({:ruleset_change, server_login, _ruleset_or_tracklist}, state) do
    case server_login == state.server.login do
      true -> {:noreply, %{state | rewrite_ruleset?: true}}
      false -> {:noreply, state}
    end
  end


  def handle_info({:tracklist_update, server_login, _ruleset_or_tracklist}, state) do
    if server_login == state.server.login do
      GenServer.cast(broker_req_pname(server_login), :reload_match_settings)
    end
    {:noreply, state}
  end


  def handle_info({:podium_start, _server_login}, state) do
    Mppm.GameServer
    |> Mppm.Repo.get(state.server.id)
    |> Mppm.Repo.preload(:ruleset)
    |> Mppm.GameRules.create_ruleset_file()
    {:noreply, state}
  end


  def handle_info({:podium_end, server_login}, state) do
    if state.server.login == server_login do
      GenServer.cast(broker_req_pname(server_login), :reload_match_settings)
    end
    {:noreply, state}
  end


  def handle_info({:end_of_game, _server_login}, state) do
    {:noreply, %{state | game_mode_id: get_next_game_mode_id(state.server.id)}}
  end


  def handle_info({:start_of_match, server_login}, state) do
    if state.server.login == server_login do
      GenServer.cast(broker_req_pname(server_login), :reload_match_settings)
    end
    {:noreply, state}
  end


  def handle_info({:current_game_mode, %Mppm.Type.GameMode{id: mode_id}}, state) do
    {:noreply, %{state | game_mode_id: mode_id}}
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

    Logger.info "[#{state.server.login}] #{latest_output}"

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

  defp proc_name(server_login), do:
    {:global, {:game_server, server_login}}

  defp broker_req_pname(server_login),
    do: {:global, {:broker_requester, server_login}}

  defp get_command(%__MODULE__{login: filename, exe_version: version}) do
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

end
