defmodule Mppm.Application do
  require Logger
  use Application

  @root_path Application.get_env(:mppm, :game_servers_root_path)

  def start(_type, _args) do
    check_install()

    children = [
      Mppm.Repo,
      MppmWeb.Endpoint,
      Mppm.Tracklist,
      Mppm.ConnectedUsers,
      Mppm.ServersStatuses,
      {
        DynamicSupervisor, strategy: :one_for_one, name: Mppm.GameServer.Supervisor
      },
      {
        DynamicSupervisor, strategy: :one_for_one, name: Mppm.FileManager.TasksSupervisor
      },
      Mppm.TracksFiles,
      %{
        id: Mppm.GameServer.Starter,
        start: {Mppm.GameServer.Starter, :start_link, []},
        restart: :temporary,
        type: :worker
      },
      Mppm.TimeTracker,
      Mppm.GameUI.GameUISupervisor,
    ]

    opts = [strategy: :one_for_one, name: Mppm.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    MppmWeb.Endpoint.config_change(changed, removed)
    :ok
  end


  def check_install() do
    Logger.info "Checking directory '#{@root_path}' exists..."
    unless File.exists?(@root_path) do
      case File.mkdir_p!(@root_path) do
        {_, :enoent} -> raise File.Error, "Couldn't create the '#{@root_path}' directory. Please check file permissions, or create the MPPM folder manually.'"
        {:error, reason} -> raise reason
        _ ->
      end
    end

    Logger.info "Checking the game server is installed..."
    try do Port.open({:spawn_executable, @root_path<>"/TrackmaniaServer"}, [:binary, args: ["/nodaemon"]])
    rescue
      ErlangError ->
        Mppm.GameServer.Server.update_game_server(@root_path)
    end

    # :ok = File.mkdir(Mppm.TracksFiles.mx_path())

    if {:ok, []} == File.ls(@root_path<>"/UserData/Maps/MX") do
      Logger.info "Copying your game server first track!"
      {:ok, _} = File.cp_r("./priv/default_tracks/", @root_path<>"/UserData/Maps/MX", fn _, _ -> false end)
    end

    if {:ok, []} == File.ls(Mppm.TracksFiles.mx_path()) do
      Logger.info "Copying your game server first track..."
      :ok = File.cp_r("./priv/default_tracks/", Mppm.TracksFiles.mx_path(), fn _, _ -> false end)
    end

    :ok
  end

end
