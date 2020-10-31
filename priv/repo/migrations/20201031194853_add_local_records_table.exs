defmodule Mppm.Repo.Migrations.AddLocalRecordsTable do
  use Ecto.Migration

  def change do
    create table(:time_records, primary_key: false) do
      add :track_id, references(:tracks), primary_key: true
      add :user_id, references(:users), primary_key: true
      add :checkpoints, {:array, :integer}
      add :lap_time, :integer
      add :race_time, :integer
    end
  end
end
