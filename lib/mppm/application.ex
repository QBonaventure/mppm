defmodule Mppm.Application do
  require Logger
  use Application


  def start(_type, _args) do
    Mppm.GameServer.DedicatedServer.check_install()
    children = [
      Mppm.Repo,
      {Phoenix.PubSub, [name: Mppm.PubSub, adapter: Phoenix.PubSub.PG2]},
      MppmWeb.Endpoint,
      Mppm.SystemWatcher,
      Mppm.Notifications,
      Mppm.ConnectedUsers,
      {
        DynamicSupervisor, strategy: :one_for_one, name: Mppm.FileManager.TasksSupervisor
      },
      Mppm.GameServer.DedicatedServer,
      {
        DynamicSupervisor, strategy: :one_for_one, name: Mppm.GameServer.Supervisor
      },
      Mppm.Tracklist,
      Mppm.TracksFiles,
      %{
        id: Mppm.GameServer.Starter,
        start: {Mppm.GameServer.Starter, :start_link, []},
        restart: :temporary,
        type: :worker
      },
      Mppm.TimeTracker,
      Mppm.GameUI.GameUISupervisor,
      Mppm.Scheduler,
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

end
