defmodule Mppm.Repo.Migrations.AddTracklistTable do
  use Ecto.Migration

  def change do
    create table(:tracklists, primary_key: false) do
      add :server_id, references(:mp_servers_configs), primary_key: true
      add :tracks_ids, {:array, :integer}
    end
  end
end
