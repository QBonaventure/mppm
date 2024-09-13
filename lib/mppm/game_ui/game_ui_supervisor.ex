defmodule Mppm.GameUI.GameUISupervisor do
  use Supervisor

  def name(server_login) do
    {:global, {:game_ui_supervisor, server_login}}
  end

  def available_modules() do
    [
      Mppm.GameUI.ChatCommands,
      Mppm.GameUI.BasicInfo,
      Mppm.GameUI.CurrentCPs,
      Mppm.GameUI.LiveRaceRanking,
      Mppm.GameUI.TimePartialsDelta,
      Mppm.GameUI.TimeRecords,
      Mppm.GameUI.MapKarma
    ]
  end

  # Return {:ok, <PID>} or :none
  def restart_module(server_login, module_name) do
    case Supervisor.terminate_child(name(server_login), module_name) do
      :ok ->
        Supervisor.restart_child(name(server_login), module_name)
      {:error, :not_found} ->
        :none
    end
  end

  def start_module(server_login, module_name) do
     Supervisor.restart_child(name(server_login), module_name)

  end

  def get_children(server_login) do
    Supervisor.which_children(name(server_login))
  end

  def child_spec(server_login) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[server_login]]},
      restart: :transient
    }
  end

  def start_link([server_login], _opts \\ []),
    do: Supervisor.start_link(__MODULE__, [server_login], name: name(server_login))

  def init([server_login]) do
    children = [
      {Mppm.GameUI.ChatCommands, [server_login]},
      {Mppm.GameUI.BasicInfo, [server_login]},
      {Mppm.GameUI.Controller, [server_login]},
      {Mppm.GameUI.CurrentCPs, [server_login]},
      {Mppm.GameUI.LiveRaceRanking, [server_login]},
      {Mppm.GameUI.TimePartialsDelta, [server_login]},
      {Mppm.GameUI.TimeRecords, [server_login]},
      {Mppm.GameUI.TrackKarma, [server_login]},
    ]
    Mppm.GameUI.Helper.toggle_base_ui(server_login, ["Race_RespawnHelper"], false)
    Supervisor.init(children, strategy: :one_for_one)
  end

end
