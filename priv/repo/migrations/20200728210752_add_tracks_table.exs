defmodule Mppm.Repo.Migrations.AddTracksTable do
  use Ecto.Migration

  def change do
    create table(:tracks) do
      add :mx_track_id, :integer
      add :uuid, :string
      add :style_id, references(:ref_track_styles)
      add :name, :string
      add :gbx_map_name, :string
      add :author_id, references(:users)
      add :laps_nb, :integer
      add :awards_nb, :integer
      add :exe_ver, :string
      add :uploaded_at, :utc_datetime
      add :updated_at, :utc_datetime
    end
    create unique_index(:tracks, [:uuid])
    create unique_index(:tracks, [:mx_track_id])
  end

end
