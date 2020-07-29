defmodule Mppm.Repo.Migrations.AddTracksTable do
  use Ecto.Migration

  def change do
    create table(:tracks) do
      add :mx_track_id, :integer
      add :track_uid, :string
      add :style_id, references(:ref_track_styles)
      add :name, :string
      add :gbx_map_name, :string
      add :author_login, :string
      add :author_id, :integer
      add :author_nickname, :string
      add :laps_nb, :integer
      add :awards_nb, :integer
      add :exe_ver, :string
      add :uploaded_at, :utc_datetime
      add :updated_at, :utc_datetime
    end
  end
  
end
