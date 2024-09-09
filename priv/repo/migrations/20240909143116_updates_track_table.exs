defmodule Mppm.Repo.Migrations.UpdatesTrackTable do
  use Ecto.Migration

  def change do
    alter table("tracks") do
      add :is_deleted, :boolean
    end
    flush()
    set_missing_values()
  end

  def down do    alter table("tracks") do
    remove :is_deleted
  end
  end

  def set_missing_values() do
    Mppm.Repo.update_all(Mppm.Track, set: [is_deleted: false])
  end

end
