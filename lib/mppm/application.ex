defmodule Mppm.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
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
      Mppm.TimeTracker
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

end
