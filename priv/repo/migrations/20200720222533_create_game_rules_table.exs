defmodule Mppm.Repo.Migrations.CreateGameRulesTable do
  use Ecto.Migration

  def change do
    create table(:game_rules, primary_key: false) do
      add :server_id, references(:mp_servers_configs, on_delete: :delete_all), primary_key: true
      add :mode_id, references(:game_modes)
      add :finish_timeout, :integer
      add :pts_limit, :integer
      add :ta_time_limit, :integer
      add :rounds_pts_limit, :integer
      add :rounds_use_new_rules, :boolean
      add :rounds_forced_laps, :integer
      add :team_max_pts, :integer
      add :team_pts_limit, :integer
      add :team_use_new_rule, :boolean
      add :laps_lap_nb, :integer
      add :laps_time_limit, :integer
    end
  end
end
