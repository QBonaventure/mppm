defmodule Mppm.GameServer.DedicatedServer do
  use GenServer
  import Ecto.Query, only: [from: 2]
  use Ecto.Schema
  import Ecto.Changeset
  require Logger

  @moduledoc """
  Takes care of everything related to dedicated server files and executables related
  """

  @allowed_statuses [:installed, :uninstalled, :in_use, :installing, :unknown]
  @root_path Application.get_env(:mppm, :game_servers_root_path)
  @user_data_path "#{@root_path}UserData"

  # @enforce_keys [:version, :release_datetime, :download_link, :status]
  # defstruct [:version, :release_datetime, :download_link, status: :unknown]
  @type t :: %__MODULE__{
      version: version(),
      release_datetime: release_datetime(),
      download_link: download_link(),
      status: atom(),
  }
  @type version :: pos_integer()
  @type download_link :: String.t()
  @type release_datetime :: DateTime.t()


  embedded_schema do
    field :version, :integer
    field :release_datetime, :utc_datetime
    field :download_link, :string
    field :status, :string
    embeds_many :servers, Mppm.GameServer.Server
  end

  @required_fields [:version, :release_datetime, :download_link, :status]
  @fields @required_fields ++ [:servers]
  def changeset(%__MODULE__{} = dedicated_server, data \\ %{}) do
    dedicated_server
    |> cast(data, @fields)
    |> validate_required(@required_fields)
  end


  @spec get(version()) :: {:ok, t()} | {:error, :not_found}
  def get(version) when is_binary(version),
    do: version |> String.to_integer() |> get()
  def get(version) do
    res =
      GenServer.call(__MODULE__, {:list_versions})
      |> Enum.find(& &1.version == version)
    case res do
      nil -> {:error, :not_found}
      dedi -> {:ok, dedi}
    end
  end

  @doc """
  Returns the system path for the given dedicated server version.

  Returns `String.t()`

  ## Examples
      iex> Mppm.GameServer.DedicatedServer.executable_path(20210208)
      "/opt/mppm/game_servers/TrackmaniaServer_20210208/TrackmaniaServer"
  """
  @spec executable_path(version()) :: binary()
  def executable_path(version) when is_integer(version) do
    "#{@root_path}TrackmaniaServer_#{version}/TrackmaniaServer"
  end


  @doc """
  Lists all available versions to be installed.

  Returns list of t()


  """
  @spec list_versions() :: [t()]
  def list_versions() do
    GenServer.call(__MODULE__, {:list_versions})
  end


  @doc """
  Lists already installed and ready to be used.

  Returns list of t()

  ## Examples
      iex> Mppm.GameServer.DedicatedServer.ready_to_use_servers()
      [
        %Mppm.GameServer.DedicatedServer{
          download_link: "http://files.v04.maniaplanet.com/server/TrackmaniaServer_2021-02-08b.zip",
          release_datetime: ~U[2021-02-12 18:28:00Z],
          status: :installed,
          version: 20210212
        },
        %Mppm.GameServer.DedicatedServer{
          download_link: "http://files.v04.maniaplanet.com/server/TrackmaniaServer_2021-02-08.zip",
          release_datetime: ~U[2021-02-08 18:17:12Z],
          status: :in_use,
          version: 20210208
        }
      ]
  """
  @spec ready_to_use_servers() :: [t()]
  def ready_to_use_servers() do
    GenServer.call(__MODULE__, {:ready_to_use_servers})
  end


  @doc """

  """
  @spec uninstall_game_server(version() | t()) :: {:ok, :uninstalling} | {:error, :in_use}
  def uninstall_game_server(version) when is_integer(version), do:
    uninstall_game_server(get(version) |> elem(1))
  def uninstall_game_server(%__MODULE__{} = dedi_server) do
    case GenServer.call(__MODULE__, {:uninstall_flag, dedi_server}) do
      {:ok, :uninstalling} ->
        File.rm_rf("#{@root_path}TrackmaniaServer_#{dedi_server.version}")
        GenServer.cast(__MODULE__, {:update_status, :uninstalled, dedi_server})
        "sdqd"
      false ->
        {:ok, :no_change}
    end
  end


  @doc """
  Installs a game server's binaries given a specific version.

  As it requires downloading files with the FileManager, it returns directly.
  """
  @spec install_game_server(version() | t()) :: {:ok, :installing | :already_installed}
  def install_game_server(version) when is_integer(version), do:
    install_game_server(get(version) |> elem(1))
  def install_game_server(%__MODULE__{} = dedi_server) do
    case GenServer.call(__MODULE__, {:install_flag, dedi_server}) do
      {:ok, :installing} ->
        {:ok, _pid} = Mppm.FileManager.TasksSupervisor.download_file(
          dedi_server.download_link,
          "/tmp/TrackmaniaServer_#{dedi_server.version}.zip",
          {&Mppm.GameServer.DedicatedServer.finish_install/2, [version: dedi_server.version] ++ opts}
        )
        {:ok, :installing}
      {:ok, :already_installed} = resp ->
        resp
    end
  end


  @doc """
  Terminates the game server installation initiated by the `install_game_server/2`
  function.
  """
  @spec finish_install(binary(), integer()) :: :ok
  def finish_install(zip_file_path, version) do
    destination_path = "#{@root_path}TrackmaniaServer_#{version}"
    File.mkdir(destination_path)

    {:ok, binary} = File.read(zip_file_path)
    File.rm(zip_file_path)

    :zip.unzip(binary, [cwd: String.to_charlist(destination_path)])

    if Keyword.get(opts, :first_install) == true do
      :ok = prepare_first_install(destination_path)
    end

    :ok = cleanup_install(destination_path)
    :ok = link_to_user_data(destination_path)
    :ok = set_executable_mode(destination_path)
    GenServer.cast(__MODULE__, {:update_status, :installed, get(version) |> elem(1)})
  end


  @doc """
  Calls the `Mppm.Service.UbiNadeoApi` for a fresh list of server versions to check
  against. If a new dedicated server has been published, adds it to the state.

  Returns `{:ok, :new_version}` if at least one new version has been added,
  `{:ok, :no_change}` otherwise
  """
  @spec check_new_versions() :: {:ok, :no_change} | {:ok, :new_version}
  def check_new_versions() do
    available = fresh_versions_list()
    in_state_version_nbs = list_versions() |> Enum.map(& &1.version)
    case Enum.reject(available, & &1.version in in_state_version_nbs) do
      [] ->
        {:ok, :no_change}
      new_versions ->
        Enum.each(new_versions, & GenServer.cast(__MODULE__, {:new_version, &1}))
        {:ok, :new_version}
    end
  end

  ############################################
  ########### GenServer callbacks ############
  ############################################


  def handle_call({:ready_to_use_servers}, _from, state) do
    ready_versions = Enum.filter(state.versions, & &1.status in [:installed, :in_use])
    {:reply, ready_versions, state}
  end

  def handle_call({:list_versions}, _from, state) do
    {:reply, state.versions, state}
  end

  def handle_call({:install_flag, %__MODULE__{} = dedi_server}, _from, state) do
      case dedi_server.status do
        :uninstalled ->
          {:ok, state} = update_dedicated_status(:installing, dedi_server, state)
          {:reply, {:ok, :installing}, state}
        _ ->
          {:reply, {:ok, :already_installed}, state}
      end
  end

  def handle_call({:uninstall_flag, %__MODULE__{} = dedi_server}, _from, state) do
      case dedi_server.status do
        :installed ->
          {:ok, state} = update_dedicated_status(:uninstalled, dedi_server, state)
          {:reply, {:ok, :uninstalling}, state}
        :in_use ->
          {:reply, {:error, :is_in_use}, state}
        _ ->
          {:reply, {:ok, :uninstalled}, state}
      end
  end


  def handle_cast({:update_status, status, %__MODULE__{} = dedicated}, state)
  when status in @allowed_statuses do
    {:ok, state} = update_dedicated_status(status, dedicated, state)
    {:noreply, state}
  end


  def handle_cast({:new_version, %__MODULE__{} = new_version}, state) do
    new_version = Map.put(new_version, :status, :uninstalled)
    {:noreply, %{state | versions: [new_version] ++ state.versions}}
  end


  def handle_info({:version_change, _server_login, %__MODULE__{} = _version}, state) do
    in_use_dedicated = in_use_servers()
    versions =
      state.versions
      |> Enum.map(fn dedicated_version ->
        case {dedicated_version.version in in_use_dedicated, dedicated_version.status} do
          {true, :installed} -> Map.put(dedicated_version, :status, :in_use)
          {false, :in_use} -> Map.put(dedicated_version, :status, :installed)
          _ -> dedicated_version
        end
      end)
    notify_if_changed(state.versions, versions)
    {:noreply, %{state | versions: versions}}
  end

  def handle_info(_msg, state), do:
    {:noreply, state}


  ############################################
  ############ Private functions #############
  ############################################


  def notify_if_changed(old_versions_list, new_versions_list)
  when old_versions_list === new_versions_list, do: :ok
  def notify_if_changed(_old_versions_list, new_versions_list) do
    Phoenix.PubSub.broadcast(Mppm.PubSub, "server-versions", {:server_versions_update, new_versions_list})
    :ok
  end

  defp server_version_installed?(version), do:
    File.exists?("#{@root_path}TrackmaniaServer_#{version}/TrackmaniaServer")

  defp in_use_servers() do
    Mppm.Repo.all(from s in Mppm.GameServer.Server, select: s.exe_version, distinct: true)
  end

  defp link_to_user_data(install_path), do:
    File.ln_s("#{@root_path}UserData", "#{install_path}/UserData")

  defp set_executable_mode(install_path) do
    case System.cmd("chmod", ["+x", "#{install_path}/TrackmaniaServer"]) do
      {"", 0} ->
        :ok
      _ ->
        {:error, "Couldn't set binary file as executable"}
    end
  end

  defp cleanup_install(install_path) do
    File.rm_rf("#{install_path}/UserData")
    File.rm_rf("#{install_path}/RemoteControlExamples")
    File.rm("#{install_path}/TrackmaniaServer.exe")
  end

  defp prepare_first_install(install_path) do
    File.cp_r("#{install_path}/UserData", @user_data_path)
    File.mkdir("#{@user_data_path}/Maps/MX")
  end

  defp cast(versions) when is_list(versions), do: Enum.map(versions, & cast(&1))
  # Casts map of server version from Mppm.Service.UbiNadeoApi to module struct.
  defp cast(%{"download_link" => download_link, "release_datetime" => release_datetime, "version" => version}), do:
    %__MODULE__{
      version: version,
      release_datetime: DateTime.from_iso8601(release_datetime) |> elem(1),
      download_link: download_link,
      status: :unknown,
    }


  def check_install() do
    Logger.info "Checking directory '#{@root_path}' exists..."
    unless File.exists?(@root_path) do
      Logger.info "Creating #{@root_path}"
      case File.mkdir_p!(@root_path) do
        {_, :enoent} ->
          raise File.Error, "Couldn't create the '#{@root_path}' directory. Please check file permissions, or create the MPPM folder manually.'"
        {:error, reason} ->
          raise reason
        _ ->
      end
    end

    if {:ok, []} == File.ls(@root_path) do
      Logger.info "No game server detected, installing the latest one..."
      Logger.info "Downloading files..."
      {:ok, %{"download_link" => download_link, "version" => version}} = Mppm.Service.UbiNadeoApi.latest_server_version()
      zip_path = "/tmp/TrackmaniaServer_#{version}.zip"

      {:ok, %HTTPoison.Response{body: body}} = HTTPoison.get(download_link)
      File.write(zip_path, body)

      Logger.info "Installing game server files..."
      finish_install(zip_path, [version: version, first_install: true])
    end

    if {:ok, []} == File.ls(Mppm.TracksFiles.mx_path()) do
      Logger.info "Copying your game server first track..."
      {:ok, [first_track_name | _]} = File.ls("./priv/default_tracks/")
      :ok = File.cp("./priv/default_tracks/#{first_track_name}", "#{Mppm.TracksFiles.mx_path()}/#{first_track_name}", fn _, _ -> false end)
    end
  end

  defp update_dedicated_status(status, %__MODULE__{version: version}, state) do
    versions =
      Enum.map(state.versions, fn dedicated_server ->
        case dedicated_server.version == version do
          true ->
            new_dedi = Map.put(dedicated_server, :status, status)
            Phoenix.PubSub.broadcast(Mppm.PubSub, "server-versions", {:status_updated, new_dedi})
            new_dedi
          false ->
            dedicated_server
        end
      end)
    {:ok, %{state | versions: versions}}
  end

  defp fresh_versions_list() do
    {:ok, list} = Mppm.Service.UbiNadeoApi.server_versions()
    cast(list)
  end

  ############################################
  ######## GenServer implementation ##########
  ############################################

  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def init(_) do
    Phoenix.PubSub.subscribe(Mppm.PubSub, "server-status")
    available_versions = fresh_versions_list()
    installed_versions =
      available_versions
      |> Enum.map(& &1.version)
      |> Enum.filter(&server_version_installed?(&1))
    versions =
      Enum.map(available_versions, fn version_map ->
        case Enum.member?(in_use_servers(), version_map.version) do
          true -> Map.put(version_map, :status, :in_use)
          false ->
            case Enum.member?(installed_versions, version_map.version) do
              true -> Map.put(version_map, :status, :installed)
              false -> Map.put(version_map, :status, :uninstalled)
            end
        end
      end)
    {:ok, %{versions: versions}}
  end


end
