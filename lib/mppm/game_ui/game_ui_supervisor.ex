defmodule Mppm.GameUI.GameUISupervisor do
  use Supervisor


  def start_child(), do: Supervisor.start_child(__MODULE__, [])
  def start_link(_init_value), do: Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  def init(nil) do
    children = [
      Mppm.GameUI.Controller,
      Mppm.GameUI.TimeRecords,
      Mppm.GameUI.LiveRaceRanking
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end

end
