defmodule Mppm.Repo.Migrations.CreateGamesModesTable do
  use Ecto.Migration

  def up do
    create table(:game_modes, primary_key: false) do
      add :id, :id, primary_key: true
      add :name, :string
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
        %{id: 0, name: "Script"},
        %{id: 1, name: "Rounds"},
        %{id: 2, name: "Time Attack"},
        %{id: 3, name: "Team"},
        %{id: 4, name: "Laps"},
        %{id: 5, name: "Cup"},
        %{id: 6, name: "Stunt"}
      ]
    )
  end

end
