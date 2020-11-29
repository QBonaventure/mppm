defmodule Mppm.Repo.Migrations.AddTrackStylesTable do
  use Ecto.Migration

  def change do
    create table(:ref_track_styles, primary_key: false) do
      add :id, :id, primary_key: true
      add :name, :string
    end
    flush()
    insert_track_styles()
  end

  def down do
    drop table(:ref_track_styles)
  end

  def insert_track_styles do
    Mppm.Repo.insert_all(
      Mppm.TrackStyle,
      [
        %{id: 1, name: "Race"},
        %{id: 2, name: "FullSpeed"},
        %{id: 3, name: "Tech"},
        %{id: 4, name: "RPG"},
        %{id: 5, name: "LOL"},
        %{id: 6, name: "Press Forward"},
        %{id: 7, name: "SpeedTech"},
        %{id: 8, name: "MultiLap"},
        %{id: 9, name: "Offroad"},
        %{id: 10, name: "Trial"},
        %{id: 11, name: "ZrT"},
        %{id: 12, name: "SpeedFun"},
        %{id: 13, name: "Competitive"},
        %{id: 14, name: "Ice"},
        %{id: 15, name: "Dirt"},
        %{id: 16, name: "Stunt"},
        %{id: 17, name: "Reactor"},
        %{id: 18, name: "Platform"},
        %{id: 19, name: "Slow Motion"},
        %{id: 20, name: "Bumper"},
        %{id: 21, name: "Fragile"},
        %{id: 22, name: "Scenery"},
        %{id: 23, name: "Kacky"},
        %{id: 24, name: "Endurance"},
        %{id: 25, name: "Mini"},
        %{id: 26, name: "Remake"},
        %{id: 27, name: "Mixed"},
        %{id: 28, name: "Nascar"},
        %{id: 29, name: "SpeedDrift"},
        %{id: 30, name: "Minigame"},
        %{id: 31, name: "Obstacle"},
        %{id: 32, name: "Transitional"},
        %{id: 33, name: "Grass"}
      ]
    )
  end

end
