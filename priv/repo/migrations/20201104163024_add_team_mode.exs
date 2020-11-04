defmodule Mppm.Repo.Migrations.AddTeamMode do
  use Ecto.Migration
  import Ecto.Query

  @team_mode_id 3

  def up do
    alter table(:game_rules) do
      add :team_respawn_behaviour_id, references(:ref_respawn_behaviours)
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
      add :team_warmup_nb, :integer, default: 0
    end
    insert_team_mode()
  end

  def down do
    alter table(:game_rules) do
      remove :team_respawn_behaviour_id
      remove :team_cumulate_pts
      remove :team_custom_pts_repartition
      remove :team_finish_timeout
      remove :team_forced_laps_nb
      remove :team_maps_per_match
      remove :team_max_players_per_team
      remove :team_min_players_per_team
      remove :team_max_pts_per_round
      remove :team_points_gap
      remove :team_pts_limit
      remove :team_pts_repartition
      remove :team_rounds_per_map
      remove :team_use_tie_breaker
      remove :team_warmup_duration
      remove :team_warmup_nb
    end
    delete_team_mode()
  end

  def insert_team_mode() do
    Mppm.Repo.insert_all(
      Mppm.Type.GameMode,
      [
        %{id: @team_mode_id, name: "Team", script_name: "Trackmania/TM_Teams_Online.Script.txt"},
      ]
    )
  end

  def delete_team_mode() do
    Mppm.Repo.delete_all(from m in Mppm.Type.GameMode, where: m.id == @team_mode_id)
  end

end
