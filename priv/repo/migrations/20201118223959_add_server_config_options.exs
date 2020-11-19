defmodule Mppm.Repo.Migrations.AddServerConfigColumns do
  use Ecto.Migration

  def change do
    alter table(:mp_servers_configs) do
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
