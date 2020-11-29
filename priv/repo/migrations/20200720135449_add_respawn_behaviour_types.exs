defmodule Mppm.Repo.Migrations.AddRespawnBehaviourTypes do
  use Ecto.Migration

  def up do
    create table(:ref_respawn_behaviours, primary_key: false) do
      add :id, :id, primary_key: true
      add :name, :string
      add :description, :string
    end
    flush()
    insert_data()
  end

  def down do
    drop table(:ref_respawn_behaviours)
  end

  def insert_data() do
    Mppm.Repo.insert_all(
      Mppm.Ruleset.RespawnBehaviour,
      [
        %{id: 0, name: "Inherit", description: "Inherits from the game mode"},
        %{id: 1, name: "Normal", description: "Player can normally respawn and give up"},
        %{id: 2, name: "No respawn/give up", description: "Players can't respawn nor give up"},
        %{id: 3, name: "At start", description: "Respawning before first CP is a give up"},
        %{id: 4, name: "All give up", description: "Players always give up"},
        %{id: 5, name: "No give up", description: "Players can respawn, no give up"},
      ]
    )
  end


end
