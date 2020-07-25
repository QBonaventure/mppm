defmodule Mppm.Repo.Migrations.CreateGameRulesTable do
  use Ecto.Migration

  def change do
    create table(:game_rules, primary_key: false) do
      add :server_id, references(:mp_servers_configs, on_delete: :delete_all), primary_key: true
      add :mode_id, references(:game_modes)

      add :ta_allow_respawn, :boolean
      add :ta_respawn_behaviour, :integer
      add :ta_time_limit, :integer
      add :ta_warmup_nb, :integer
      add :ta_warmup_duration, :integer
      add :ta_forced_laps_nb, :integer
      ### adds for Rounds
      add :rounds_allow_respawn, :boolean
      add :rounds_respawn_behaviour, :integer
      add :rounds_pts_limit, :integer
      add :rounds_finish_timeout, :integer
      add :rounds_use_alternate_rules, :boolean
      add :rounds_forced_laps_nb, :integer
      add :rounds_maps_per_match, :integer
      add :rounds_rounds_per_map, :integer
      add :rounds_warmup_nb, :integer
      add :rounds_warmup_duration, :integer
      add :rounds_pts_repartition, :string
    end
  end
end
