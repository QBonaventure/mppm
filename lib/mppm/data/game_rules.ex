defmodule Mppm.GameRules do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias __MODULE__
  alias Mppm.Repo
  import Record

  defrecord(:xmlElement, extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl"))
  defrecord(:xmlAttribute, extract(:xmlAttribute, from_lib: "xmerl/include/xmerl.hrl"))
  defrecord(:xmlText, extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl"))

  # @app_path Application.get_env(:mppm, :app_path)
  @root_path Application.get_env(:mppm, :mp_servers_root_path)
  @config_path @root_path <> "UserData/Config/"
  @maps_path @root_path <> "UserData/Maps/"

  @primary_key {:server_id, :id, autogenerate: false}
  schema "game_rules" do
    belongs_to :server, Mppm.ServerConfig, foreign_key: :id, primary_key: true, define_field: false
    belongs_to :mode, Mppm.Type.GameMode
    field :finish_timeout, :integer, default: 20
    ### Fields for TA
    field :ta_time_limit, :integer, default: 6000
    ### Fields for Rounds
    field :rounds_pts_limit, :integer, default: 50
    field :rounds_use_new_rules, :boolean, default: true
    field :rounds_forced_laps, :integer, default: 3
    ### Fields for Team
    field :team_max_pts, :integer, default: 50
    field :team_pts_limit, :integer, default: 8
    field :team_use_new_rule, :boolean, default: true
    ### Fields for Laps
    field :laps_lap_nb, :integer, default: 3
    field :laps_time_limit, :integer, default: 20
###ChatTime, TimeAttackSynchStartPeriod, FinishTimeout
  end

  @integer_fields [
    :finish_timeout, :ta_time_limit, :rounds_pts_limit,
    :rounds_forced_laps, :team_max_pts, :team_pts_limit, :laps_lap_nb,
    :laps_time_limit
  ]
  @all_fields @integer_fields ++ [
    :server_id, :mode_id, :rounds_use_new_rules, :team_use_new_rule
  ]


  def changeset(%GameRules{} = ruleset, data) do
    ruleset
    |> cast(data, @all_fields)
    # |> cast_assoc(:server)
    |> cast_assoc(:mode)
  end

  def get_options_list(), do:
    List.delete(@all_fields, :server_id)


end
