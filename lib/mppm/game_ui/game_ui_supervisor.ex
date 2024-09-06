defmodule Mppm.GameUI.GameUISupervisor do
  use Supervisor

  def available_modules() do
    [
      Mppm.GameUI.ChatCommands,
      Mppm.GameUI.BasicInfo,
      Mppm.GameUI.CurrentCPs,
      Mppm.GameUI.LiveRaceRanking,
      Mppm.GameUI.TimePartialsDelta,
      Mppm.GameUI.TimeRecords
    ]
  end

  def active_modules(_server_login) do
    Supervisor.which_children({:global, {:game_ui_supervisor, "ftc_tm20_5"}})
    |> Enum.map(fn {module, pid, _, _} -> {module, pid} end)
  end

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
      {Mppm.GameUI.ChatCommands, [server_login]},
      {Mppm.GameUI.BasicInfo, [server_login]},
      {Mppm.GameUI.Controller, [server_login]},
      {Mppm.GameUI.CurrentCPs, [server_login]},
      {Mppm.GameUI.LiveRaceRanking, [server_login]},
      {Mppm.GameUI.TimePartialsDelta, [server_login]},
      {Mppm.GameUI.TimeRecords, [server_login]},
    ]
    Mppm.GameUI.Helper.toggle_base_ui(server_login, ["Race_RespawnHelper"], false)
    Supervisor.init(children, strategy: :one_for_one)
  end

end
