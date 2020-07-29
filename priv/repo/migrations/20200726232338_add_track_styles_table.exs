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
        %{id: 2, name: "Fullspeed"},
        %{id: 3, name: "Tech"},
        %{id: 4, name: "RPG"},
        %{id: 5, name: "LOL"},
        %{id: 6, name: "Press Forward"},
        %{id: 7, name: "Speedtech"},
        %{id: 8, name: "Multilap"},
        %{id: 9, name: "Offroad"},
        %{id: 10, name: "Trial"}
      ]
    )
  end

end
