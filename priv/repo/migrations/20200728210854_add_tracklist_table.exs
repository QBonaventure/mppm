defmodule Mppm.Repo.Migrations.AddTracklistTable do
  use Ecto.Migration

  def change do
    create table(:tracklists) do
      add :server_id, references(:mp_servers_configs)
      add :map_id, references(:tracks)
      add :index, :integer
    end
    create unique_index(:tracklists, [:server_id, :map_id, :index], name: :uk_tracklist_tracks)
  end
end
