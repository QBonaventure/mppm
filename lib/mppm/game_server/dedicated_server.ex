defmodule Mppm.GameServer.DedicatedServer do
  use GenServer
  import Ecto.Query, only: [from: 2]
  require Logger

  @moduledoc """
  Takes care of everything dedicated server files and executables related
  """

  @allowed_statuses [:installed, :uninstalled, :in_use, :installing, :downloading, :unknown]
  @root_path Application.get_env(:mppm, :game_servers_root_path)
  @user_data_path "#{@root_path}UserData"

  @enforce_keys [:version, :release_datetime, :download_link, :status]
  defstruct [:version, :release_datetime, :download_link, status: :unknown]
  @type t :: %__MODULE__{
      version: version(),
      release_datetime: release_datetime(),
      download_link: download_link(),
      status: atom(),
  }
  @type version :: pos_integer()
  @type download_link :: string()
  @type release_datetime :: DateTime.t()

  @doc """
  Returns the system path for the given dedicated server version.

  Returns `String.t()`

  ## Examples
      iex> Mppm.GameServer.DedicatedServer.executable_path(20210208)
      "/opt/mppm/game_servers/TrackmaniaServer_20210208/TrackmaniaServer"
  """
  @spec executable_path(version()) :: release_datetime()
  def executable_path(version) when is_integer(version) do
    "#{@root_path}TrackmaniaServer_#{version}/TrackmaniaServer"
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
  @spec ready_to_use_servers() :: [t]
  def ready_to_use_servers() do
    GenServer.call(__MODULE__, {:ready_to_use_servers})
  end

  @doc """
  Installs a game server's binaries given a specific version.

  As it requires downloading files with the FileManager, it returns directly.
  """
  def install_game_server(version, opts \\ []) when is_integer(version) do
    {:ok, server_versions} = Mppm.Service.UbiNadeoApi.server_versions()
    file_url = Enum.find(server_versions, & &1["version"] == version) |> Map.get("download_link")
    {:ok, _pid} = Mppm.FileManager.TasksSupervisor.download_file(
      file_url,
      "/tmp/TrackmaniaServer_#{version}.zip",
      {&Mppm.GameServer.DedicatedServer.finish_install/2, [version: version] ++ opts}
    )
  end


  @doc """
  Terminates the game server installation initiated by the `install_game_server/2`
  function.
  """
  @spec finish_install(binary(), []) :: :ok
  def finish_install(zip_file_path, opts) do
    version = Keyword.get(opts, :version)
    destination_path = "#{@root_path}TrackmaniaServer_#{version}"
    File.mkdir(destination_path)
IO.inspect "------------- FINISH INSTALL --------------------"
    {:ok, binary} = File.read(zip_file_path)
    File.rm(zip_file_path)

    :zip.unzip(binary, [cwd: String.to_charlist(destination_path)])

    if Keyword.get(opts, :first_install) == true do
      :ok = prepare_first_install(destination_path)
    end

    :ok = cleanup_install(destination_path)
    :ok = link_to_user_data(destination_path)
    :ok = set_executable_mode(destination_path)
  end



  ############################################
  ########### GenServer callbacks ############
  ############################################

  def handle_call({:ready_to_use_servers}, _from, state) do
    ready_versions = Enum.filter(state.versions, & &1.status in [:installed, :in_use])
    {:reply, ready_versions, state}
  end



  ############################################
  ############ Private functions #############
  ############################################

  defp server_version_installed?(version), do:
    File.exists?("#{@root_path}TrackmaniaServer_#{version}/TrackmaniaServer")

  defp in_use_servers() do
    Mppm.Repo.all(from s in Mppm.ServerConfig, select: s.version, distinct: true)
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
      install_path = "#{@root_path}TrackmaniaServer_#{version}"
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

  ############################################
  ######## GenServer implementation ##########
  ############################################

  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def init(_) do
    available_versions = Mppm.Service.UbiNadeoApi.server_versions() |> elem(1) |> cast()
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
