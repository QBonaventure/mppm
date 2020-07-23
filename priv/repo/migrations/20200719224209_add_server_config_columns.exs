defmodule Mppm.Repo.Migrations.AddServerConfigColumns do
  use Ecto.Migration

  def change do
    alter table(:mp_servers_configs) do
      add :keep_player_slot, :boolean, default: false
      add :autosave_replays, :boolean, default: false
      add :autosave_validation_replays, :boolean, default: false
      add :disable_horns, :boolean, default: false
      add :ip_address, :inet, default: fragment("'0.0.0.0'::inet")
      add :bind_ip, :inet, default: fragment("'0.0.0.0'::inet")
    end

    end

end
