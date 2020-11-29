defmodule Mppm.Repo.Migrations.AddsTracksMxTags do
  use Ecto.Migration

  def change do
    create table(:rel_tracks_tags, primary_key: false) do
      add(:track_id, references(:tracks, on_delete: :delete_all), primary_key: true)
      add(:track_style_id, references(:ref_track_styles, on_delete: :delete_all), primary_key: true)
    end
    create(index(:rel_tracks_tags, [:track_id]))
    create(index(:rel_tracks_tags, [:track_style_id]))
  end

  def down do
    drop table(:rel_tracks_tags)
  end


end
