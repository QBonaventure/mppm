defmodule Mppm.GameUI.GameUISupervisor do
  use Supervisor

  def child_spec(server_login) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[server_login]]},
      restart: :transient
    }
  end

  def start_link([server_login], _opts \\ []),
    do: Supervisor.start_link(__MODULE__, [server_login], name: {:global, {:game_ui_supervisor, server_login}})

  def init([server_login]) do
    children = [
      {Mppm.GameUI.BasicInfo, [server_login]},
      {Mppm.GameUI.Controller, [server_login]},
      {Mppm.GameUI.LiveRaceRanking, [server_login]},
      {Mppm.GameUI.TimePartialsDelta, [server_login]},
      {Mppm.GameUI.TimeRecords, [server_login]},
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end

end
