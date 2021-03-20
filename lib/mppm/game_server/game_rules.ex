defmodule Mppm.GameRules do
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__
  alias Mppm.GameServer.Server
  require Logger

  @root_path Application.get_env(:mppm, :game_servers_root_path)
  @maps_path @root_path <> "UserData/Maps/"

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
    belongs_to :server, Mppm.GameServer.Server, primary_key: true, define_field: false
    belongs_to :mode, Mppm.Type.GameMode, foreign_key: :mode_id
    ### Fields for TA
    belongs_to :ta_respawn_behaviour, Mppm.Ruleset.RespawnBehaviour, foreign_key: :ta_respawn_behaviour_id, define_field: false
    field :ta_respawn_behaviour_id, :integer, read_after_writes: true
    field :ta_time_limit, :integer, default: 600
    field :ta_warmup_nb, :integer, default: 0
    field :ta_warmup_duration, :integer, default: 0
    field :ta_forced_laps_nb, :integer, default: 0
    ### Fields for Rounds
    belongs_to :rounds_respawn_behaviour, Mppm.Ruleset.RespawnBehaviour, foreign_key: :rounds_respawn_behaviour_id, define_field: false
    field :rounds_respawn_behaviour_id, :integer, read_after_writes: true
    field :rounds_pts_limit, :integer, default: 100
    field :rounds_finish_timeout, :integer, default: -1
    field :rounds_forced_laps_nb, :integer, default: 3
    field :rounds_maps_per_match, :integer, default: -1
    field :rounds_rounds_per_map, :integer, default: -1
    field :rounds_warmup_nb, :integer, default: 0
    field :rounds_warmup_duration, :integer, default: 0
    field :rounds_pts_repartition, :string, default: ""
    ### Fields for Team
    belongs_to :team_respawn_behaviour, Mppm.Ruleset.RespawnBehaviour, foreign_key: :team_respawn_behaviour_id, define_field: false
    field :team_respawn_behaviour_id, :integer, read_after_writes: true
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


  def changeset(%GameRules{} = ruleset, data \\ %{}) do
    data =
      data
      |> Map.put_new("ta_respawn_behaviour_id", 0)
    ruleset
    |> cast(data, @all_fields)
    |> cast_assoc(:mode)
    |> cast_assoc(:ta_respawn_behaviour)
    |> cast_assoc(:rounds_respawn_behaviour)
    |> cast_assoc(:team_respawn_behaviour)
    |> validate_number(:ta_warmup_nb, greater_than_or_equal_to: 0)
    |> validate_number(:ta_time_limit, greater_than_or_equal_to: 0)
  end

  def get_options_list(),
    do: List.delete(@all_fields, :server_id)


  def create_ruleset_file(%Server{ruleset: %Ecto.Association.NotLoaded{}} = server),
    do: server |> Mppm.Repo.preload(ruleset: [:mode]) |> create_ruleset_file()
  def create_ruleset_file(%Server{ruleset: %Mppm.GameRules{mode: %Ecto.Association.NotLoaded{}}} = server),
    do: server |> Mppm.Repo.preload(ruleset: [:mode]) |> create_ruleset_file()
  def create_ruleset_file(%Server{ruleset: ruleset} = server) do
    target_path = "#{@maps_path}MatchSettings/#{server.login}.txt"

    script_settings = {
      :mode_script_settings,
      [],
      Mppm.GameRules.get_script_variables_by_mode(ruleset.mode)
      |> Enum.map(fn {key, value} ->
        {:setting, [
          name: value,
          type: Mppm.XML.get_type(Map.get(ruleset, key)),
          value: Mppm.XML.script_setting_value_correction(Map.get(ruleset, key))], []}
      end)
    }

    game_info = {:gameinfos, [], [
      {:game_mode, [], [Mppm.XML.charlist(0)]},
      {:script_name, [], [Mppm.XML.charlist(ruleset.mode.script_name)]}
    ]}

    tracklist =
      case File.exists?(target_path) do
        true ->
          Mppm.XML.from_file(target_path)
        false ->
          Mppm.XML.from_file("#{@maps_path}MatchSettings/tracklist.txt")
      end
      |> elem(2)
      |> Enum.filter(fn {v, _, _} -> Enum.member?([:map, :startindex], v) end)

    new_xml =
      {:playlist, [], [game_info, script_settings] ++ tracklist}
      |> List.wrap
      |> :xmerl.export_simple(:xmerl_xml)
      |> List.flatten

    Logger.info "["<>server.login<>"] Writing new ruleset"
    :ok = :file.write_file(target_path, new_xml)

    {:ok, target_path}
  end


  def propagate_ruleset_changes(%Ecto.Changeset{data: %Server{} = server, changes: %{ruleset: %{changes: ruleset_changes}}}) do
    mode_vars = get_script_variables_by_mode(server.ruleset.mode_id)
    to_update = Enum.filter(ruleset_changes, fn {key, _value} -> Map.has_key?(mode_vars, key) end)

    Mppm.Repo.get(Mppm.GameServer.Server, server.id)
    |> create_ruleset_file()


    Mppm.Broker.RequesterServer.update_ruleset(server.login, to_update)

    if switch_game_mode?(ruleset_changes) do
      mode = Mppm.Repo.get(Mppm.Type.GameMode, ruleset_changes.mode_id)
      Mppm.Broker.RequesterServer.switch_game_mode(server.login, mode)
    end
    :ok
  end
  def propagate_ruleset_changes(_changeset), do: :none

  def switch_game_mode?(%{mode_id: _}), do: true
  def switch_game_mode?(_), do: false

end
