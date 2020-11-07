defmodule Mppm.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @root_path Application.get_env(:mppm, :mp_servers_root_path)
  # @root_path "/opt/mppmTest/TrackmaniaServerTest"

  def start(_type, _args) do
    check_install()
    # List all child processes to be supervised
    children = [
      # Start the Ecto repository
      Mppm.Repo,
      # Start the endpoint when the application starts
      MppmWeb.Endpoint,
      Mppm.ConnectedUsers,
      Mppm.ServerConfigStore,
      Mppm.Statuses,
      # Starts a worker by calling: Mppm.Worker.start_link(arg)
      # {Mppm.Worker, arg},
      {
        DynamicSupervisor, strategy: :one_for_one, name: Mppm.ManiaplanetServerSupervisor
      },
      # hostname: "localhost", username: "postgres", password: "postgres", database: "postgres"
      # ,
      # %{
      #   id: Mppm.ServerStatusPubSub,
      #   start: {Phoenix.PubSub, :start_link, []}
      # }
      Mppm.TracksFiles,
      %{
        id: Mppm.ManiaplanetServerSupervisorStarter,
        start: {Mppm.GameServerSupervisor.Starter, :start_link, []},
        restart: :temporary,
        type: :worker
      },
      Mppm.TimeTracker,
      Mppm.GameUI.GameUISupervisor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
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
    IO.puts "Checking directory '#{@root_path}' exists..."
    unless File.exists?(@root_path) do
      case File.mkdir_p!(@root_path) do
        {_, :enoent} -> raise File.Error, "Couldn't create the '#{@root_path}' directory. Please check file permissions, or create the MPPM folder manually.'"
        {:error, reason} -> raise reason
        _ ->
      end
    end

    IO.puts "Checking the game server is installed..."
    try do Port.open({:spawn_executable, @root_path<>"/TrackmaniaServer"}, [:binary, args: ["/nodaemon"]])
    rescue
      ErlangError ->
        Mppm.ManiaplanetServer.update_game_server(@root_path)
    end

    :ok == File.mkdir(Mppm.TracksFiles.mx_path())

    if {:ok, []} == File.ls(@root_path<>"/UserData/Maps/MX") do
      IO.puts "Copying your game server first track!"
      {:ok, _} = File.cp_r("./priv/default_tracks/", @root_path<>"/UserData/Maps/MX", fn _, _ -> false end)
    end

    if {:ok, []} == File.ls(Mppm.TracksFiles.mx_path()) do
      IO.puts "Copying your game server first track..."
      :ok = File.cp_r("./priv/default_tracks/", Mppm.TracksFiles.mx_path(), fn _, _ -> false end)
    end

    :ok
  end

end
