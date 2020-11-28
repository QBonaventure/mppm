defmodule Mppm.Repo.Migrations.SetsDefaultRulesetValues do
  use Ecto.Migration
  import Ecto.Query

  def up do
    alter table(:game_rules) do
      modify :ta_respawn_behaviour_id, :integer, default: 0
      modify :rounds_respawn_behaviour_id, :integer, default: 0
      modify :team_respawn_behaviour_id, :integer, default: 0
    end

    values_set = [
      ta_respawn_behaviour_id: 0,
      rounds_respawn_behaviour_id: 0,
      team_respawn_behaviour_id: 0,
    ]

    from(g in Mppm.GameRules, where: is_nil(g.ta_respawn_behaviour_id))
    |> Mppm.Repo.update_all(set: values_set)
  end

  def down do
    alter table(:game_rules) do
      modify :ta_respawn_behaviour_id, :integer, default: nil
      modify :rounds_respawn_behaviour_id, :integer, default: nil
      modify :team_respawn_behaviour_id, :integer, default: nil
    end
  end

end
