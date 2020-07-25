defmodule Mppm.Repo.Migrations.CreateGamesModesTable do
  use Ecto.Migration

  def up do
    create table(:game_modes, primary_key: false) do
      add :id, :id, primary_key: true
      add :name, :string
      add :script_name, :string
    end
    flush()
    insert_games_modes()
  end

  def down do
    drop table("game_modes")
  end

  def insert_games_modes do
    Mppm.Repo.insert_all(
      Mppm.Type.GameMode,
      [
        %{id: 1, name: "Time Attack", script_name: "Trackmania/TM_TimeAttack_Online.Script.txt"},
        %{id: 2, name: "Rounds", script_name: "Trackmania/TM_Rounds_Online.Script.txt"},
      ]
    )
  end

end
