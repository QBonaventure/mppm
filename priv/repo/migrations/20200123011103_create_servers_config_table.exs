defmodule Mppm.Repo.Migrations.CreateServersConfigTable do
  use Ecto.Migration

  def change do
    create table(:servers_configs) do
      add :server_id, references(:servers, on_delete: :delete_all), primary_key: true
      add :max_players, :integer
      add :player_pwd, :string
      add :spec_pwd, :string
      add :superadmin_pass, :string
      add :admin_pass, :string
      add :user_pass, :string
      add :keep_player_slot, :boolean, default: false
      add :autosave_replays, :boolean, default: false
      add :autosave_validation_replays, :boolean, default: false
      add :disable_horns, :boolean, default: false
      add :ip_address, :inet, default: fragment("'0.0.0.0'::inet")
      add :bind_ip, :inet, default: fragment("'0.0.0.0'::inet")
      add :client_inputs_max_latency, :integer, default: 100
      add :connection_upload_rate, :integer, default: 500000
      add :connection_download_rate, :integer, default: 500000
      add :packet_assembly_multithread, :boolean, default: true
      add :packets_per_frame, :integer, default: 0
      add :full_packets_per_frame, :integer, default: 10
      add :trust_client_to_server_sending_rate, :integer, default: 64
      add :visuals_server_to_client_sending_rate, :integer, default: 64
      add :workers_nb, :integer, default: 2
      add :disable_replay_recording, :boolean, default: true
      add :visuals_delay, :integer, default: 400
    end
  end
end
