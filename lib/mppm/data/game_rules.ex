defmodule Mppm.GameRules do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias __MODULE__
  alias Mppm.Repo
  import Record

  @script_settings %{
    :time_attack => %{
      ta_respawn_behaviour_id: "S_RespawnBehaviour",
      ta_time_limit: "S_TimeLimit",
      ta_warmup_nb: "S_WarmUpNb",
      ta_warmup_duration: "S_WarmUpDuration",
      ta_forced_laps_nb: "S_ForceLapsNb",
    },
    :rounds => %{
      rounds_pts_limit: "S_PointsLimit",
      rounds_finish_timeout: "S_FinishTimeout",
      rounds_forced_laps_nb: "S_ForcedLapsNb",
      rounds_maps_per_match: "S_MapsPerMatch",
      rounds_rounds_per_map: "S_RoundsPerMap",
      rounds_warmup_nb: "S_WarmUpNb",
      rounds_warmup_duration: "S_WarmUpDuration",
      rounds_pts_repartition: "S_PointsRepartition",
    }
  }

  def get_script_variables_by_mode(1), do: @script_settings.time_attack
  def get_script_variables_by_mode(%Mppm.Type.GameMode{name: "Time Attack"}), do: @script_settings.time_attack
  def get_script_variables_by_mode(2), do: @script_settings.rounds
  def get_script_variables_by_mode(%Mppm.Type.GameMode{name: "Rounds"}), do: @script_settings.rounds

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
  end

  @modes_fields [
    :ta_time_limit, :ta_warmup_nb,
    :ta_warmup_duration,

    :rounds_pts_limit, :rounds_finish_timeout,
    :rounds_forced_laps_nb, :rounds_maps_per_match, :rounds_rounds_per_map,
    :rounds_warmup_nb, :rounds_warmup_duration, :rounds_pts_repartition
  ]
  @all_fields @modes_fields ++ [
    :server_id, :mode_id, :ta_respawn_behaviour_id, :rounds_respawn_behaviour_id
  ]


  def changeset(%GameRules{} = ruleset, data) do
    ruleset
    |> cast(data, @all_fields)
    |> cast_assoc(:mode)
    |> cast_assoc(:ta_respawn_behaviour)
    |> cast_assoc(:rounds_respawn_behaviour)
  end

  def get_options_list(), do:
    List.delete(@all_fields, :server_id)


end
