defmodule Mppm.Repo.Migrations.AddMapKarmaTable do
  use Ecto.Migration

  def change do
    create table(:maps_karma, primary_key: false) do
      add :track_id, references(:tracks), primary_key: true
      add :user_id, references(:users), primary_key: true
      add :note, :integer
    end
  end
end
