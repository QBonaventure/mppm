defmodule Mppm.Application do
  require Logger
  use Application


  def start(_type, _args) do

    children = [
      Mppm.Repo,
      {Phoenix.PubSub, [name: Mppm.PubSub, adapter: Phoenix.PubSub.PG2]},
      MppmWeb.Endpoint,
      Mppm.Tracklist,
      Mppm.Notifications,
      Mppm.ConnectedUsers,
      {
        DynamicSupervisor, strategy: :one_for_one, name: Mppm.FileManager.TasksSupervisor
      },
      Mppm.GameServer.DedicatedServer,
      {
        DynamicSupervisor, strategy: :one_for_one, name: Mppm.GameServer.Supervisor
      },
      Mppm.TracksFiles,
      Mppm.TimeTracker,
      Mppm.Scheduler,
      Mppm.SystemWatcher,
      %{
        id: Mppm.GameServer.Starter,
        start: {Mppm.GameServer.Starter, :start_link, []},
        restart: :temporary,
        type: :worker
      },
    ]

    opts = [strategy: :one_for_one, name: Mppm.Supervisor]
    case Supervisor.start_link(children, opts) do
      {:error, message} ->
        message
      {:ok, pid} ->
        Mppm.User.check_install()
        Mppm.GameServer.DedicatedServer.check_install()
        {:ok, pid}
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    MppmWeb.Endpoint.config_change(changed, removed)
    :ok
  end

end
