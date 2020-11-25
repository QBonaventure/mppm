defmodule Mppm.GameRules do
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__

  @script_settings %{
    :time_attack => %{
      ta_respawn_behaviour_id: "S_RespawnBehaviour",
      ta_time_limit: "S_TimeLimit",
      ta_warmup_nb: "S_WarmUpNb",
      ta_warmup_duration: "S_WarmUpDuration",
      ta_forced_laps_nb: "S_ForceLapsNb",
    },
    :rounds => %{
      rounds_respawn_behaviour_id: "S_RespawnBehaviour",
      rounds_pts_limit: "S_PointsLimit",
      rounds_finish_timeout: "S_FinishTimeout",
      rounds_forced_laps_nb: "S_ForceLapsNb",
      rounds_maps_per_match: "S_MapsPerMatch",
      rounds_rounds_per_map: "S_RoundsPerMap",
      rounds_warmup_nb: "S_WarmUpNb",
      rounds_warmup_duration: "S_WarmUpDuration",
      rounds_pts_repartition: "S_PointsRepartition",
    },
    :team => %{
      team_respawn_behaviour_id: "S_RespawnBehaviour",
      team_pts_limit: "S_PointsLimit",
      team_max_pts_per_round: "S_MaxPointsPerRound",
      team_points_gap: "S_PointsGap",
      team_custom_pts_repartition: "S_UseCustomPointsRepartition",
      team_cumulate_pts: "S_CumulatePoints",
      team_rounds_per_map: "S_RoundsPerMap",
      team_maps_per_match: "S_MapsPerMatch",
      team_use_tie_breaker: "S_UseTieBreak",
      team_warmup_nb: "S_WarmUpNb",
      team_warmup_duration: "S_WarmUpDuration",
      team_max_players_per_team: "S_NbPlayersPerTeamMax",
      team_min_players_per_team: "S_NbPlayersPerTeamMin",
      team_finish_timeout: "S_FinishTimeout",
      team_forced_laps_nb: "S_ForceLapsNb",
      team_pts_repartition: "S_PointsRepartition",
    }
  }

  def get_script_variables_by_mode(1), do: @script_settings.time_attack
  def get_script_variables_by_mode(%Mppm.Type.GameMode{name: "Time Attack"}), do: @script_settings.time_attack
  def get_script_variables_by_mode(2), do: @script_settings.rounds
  def get_script_variables_by_mode(%Mppm.Type.GameMode{name: "Rounds"}), do: @script_settings.rounds
  def get_script_variables_by_mode(3), do: @script_settings.team
  def get_script_variables_by_mode(%Mppm.Type.GameMode{name: "Team"}), do: @script_settings.team


  def get_script_settings_variables(), do: @script_settings
  def get_flat_script_variables(), do:
    Map.merge(@script_settings.time_attack, @script_settings.rounds)

  @primary_key {:server_id, :id, autogenerate: false}
  schema "game_rules" do
    belongs_to :server, Mppm.ServerConfig, foreign_key: :id, primary_key: true, define_field: false
    belongs_to :mode, Mppm.Type.GameMode, foreign_key: :mode_id
    ### Fields for TA
    belongs_to :ta_respawn_behaviour, Mppm.Ruleset.RespawnBehaviour, foreign_key: :ta_respawn_behaviour_id
    field :ta_time_limit, :integer, default: 600
    field :ta_warmup_nb, :integer, default: 0
    field :ta_warmup_duration, :integer, default: 0
    field :ta_forced_laps_nb, :integer, default: 0
    ### Fields for Rounds
    belongs_to :rounds_respawn_behaviour, Mppm.Ruleset.RespawnBehaviour, foreign_key: :rounds_respawn_behaviour_id
    field :rounds_pts_limit, :integer, default: 100
    field :rounds_finish_timeout, :integer, default: -1
    field :rounds_forced_laps_nb, :integer, default: 3
    field :rounds_maps_per_match, :integer, default: -1
    field :rounds_rounds_per_map, :integer, default: -1
    field :rounds_warmup_nb, :integer, default: 0
    field :rounds_warmup_duration, :integer, default: 0
    field :rounds_pts_repartition, :string, default: ""
    ### Fields for Team
    belongs_to :team_respawn_behaviour, Mppm.Ruleset.RespawnBehaviour, foreign_key: :team_respawn_behaviour_id
    field :team_cumulate_pts, :boolean, default: false
    field :team_custom_pts_repartition, :boolean, default: false
    field :team_finish_timeout, :integer, default: -1
    field :team_forced_laps_nb, :integer, default: 5
    field :team_maps_per_match, :integer, default: 0
    field :team_max_players_per_team, :integer, default: 3
    field :team_min_players_per_team, :integer, default: 3
    field :team_max_pts_per_round, :integer, default: 6
    field :team_points_gap, :integer, default: 1
    field :team_pts_limit, :integer, default: 5
    field :team_pts_repartition, :string, default: ""
    field :team_rounds_per_map, :integer, default: 0
    field :team_use_tie_breaker, :boolean, default: false
    field :team_warmup_duration, :integer, default: 0
    field :team_warmup_nb, :integer, default: 0
  end

  @modes_fields [
    :ta_time_limit, :ta_warmup_nb,
    :ta_warmup_duration,

    :rounds_pts_limit, :rounds_finish_timeout,
    :rounds_forced_laps_nb, :rounds_maps_per_match, :rounds_rounds_per_map,
    :rounds_warmup_nb, :rounds_warmup_duration, :rounds_pts_repartition,

    :team_cumulate_pts, :team_custom_pts_repartition, :team_finish_timeout,
    :team_forced_laps_nb, :team_maps_per_match, :team_max_players_per_team,
    :team_max_pts_per_round, :team_min_players_per_team, :team_points_gap,
    :team_pts_limit, :team_pts_repartition, :team_rounds_per_map,
    :team_use_tie_breaker, :team_warmup_duration, :team_warmup_nb
  ]
  @all_fields @modes_fields ++ [
    :server_id, :mode_id, :ta_respawn_behaviour_id, :rounds_respawn_behaviour_id, :team_respawn_behaviour_id
  ]


  def changeset(%GameRules{} = ruleset, data) do
    ruleset
    |> cast(data, @all_fields)
    |> cast_assoc(:mode)
    |> cast_assoc(:ta_respawn_behaviour)
    |> cast_assoc(:rounds_respawn_behaviour)
    |> cast_assoc(:team_respawn_behaviour)
  end

  def get_options_list(), do:
    List.delete(@all_fields, :server_id)


end
