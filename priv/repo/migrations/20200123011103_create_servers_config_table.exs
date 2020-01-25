defmodule Mppm.Repo.Migrations.CreateServersConfigTable do
  use Ecto.Migration

  def change do
    create table(:mp_servers_configs) do
      add :login, :string
      add :password, :string
      add :title_pack, :string
      add :name, :string
      add :comment, :string
      add :max_players, :integer
      add :player_pwd, :string
      add :spec_pwd, :string
      add :superadmin_pass, :string
      add :admin_pass, :string
      add :user_pass, :string
      add :validation_key, :string
    end

    create unique_index(:mp_servers_configs, [:login], name: :uk_server_configs_login)
  end
end
