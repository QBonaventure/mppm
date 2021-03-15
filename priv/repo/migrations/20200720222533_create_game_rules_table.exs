defmodule Mppm.Repo.Migrations.CreateGameRulesTable do
  use Ecto.Migration

  def change do
    create table(:game_rules, primary_key: false) do
      add :server_id, references(:servers, on_delete: :delete_all), primary_key: true
      add :mode_id, references(:game_modes)

      ### Time Attack
      add :ta_respawn_behaviour_id, references(:ref_respawn_behaviours), default: 0
      add :ta_time_limit, :integer, default: 600
      add :ta_warmup_nb, :integer, default: 0
      add :ta_warmup_duration, :integer, default: 120
      add :ta_forced_laps_nb, :integer, default: 0

      ### Rounds
      add :rounds_respawn_behaviour_id, references(:ref_respawn_behaviours), default: 0
      add :rounds_pts_limit, :integer, default: 0
      add :rounds_finish_timeout, :integer, default: 15
      add :rounds_use_alternate_rules, :boolean, default: false
      add :rounds_forced_laps_nb, :integer, default: 0
      add :rounds_maps_per_match, :integer, default: 0
      add :rounds_rounds_per_map, :integer, default: 0
      add :rounds_warmup_nb, :integer, default: 2
      add :rounds_warmup_duration, :integer, default: 0
      add :rounds_pts_repartition, :string

      ### Team
      add :team_respawn_behaviour_id, references(:ref_respawn_behaviours), default: 0
      add :team_cumulate_pts, :boolean, default: false
      add :team_custom_pts_repartition, :boolean, default: false
      add :team_finish_timeout, :integer, default: -1
      add :team_forced_laps_nb, :integer, default: 5
      add :team_maps_per_match, :integer, default: 0
      add :team_max_players_per_team, :integer, default: 3
      add :team_min_players_per_team, :integer, default: 3
      add :team_max_pts_per_round, :integer, default: 6
      add :team_points_gap, :integer, default: 1
      add :team_pts_limit, :integer, default: 5
      add :team_pts_repartition, :string, default: ""
      add :team_rounds_per_map, :integer, default: 0
      add :team_use_tie_breaker, :boolean, default: false
      add :team_warmup_duration, :integer, default: 0
      add :team_warmup_nb, :integer, default: 2
    end
  end

end
