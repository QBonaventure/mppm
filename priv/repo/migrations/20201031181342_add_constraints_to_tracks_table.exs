defmodule Mppm.Repo.Migrations.AddConstraintsToTracksTable do
  use Ecto.Migration

  def change do
    create unique_index(:tracks, [:track_uid])
  end
end
