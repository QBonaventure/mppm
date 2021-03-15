defmodule Mppm.Repo.Migrations.CreateServersTable do
  use Ecto.Migration

  def up do
    create table(:servers) do
      add :login, :string
      add :password, :string
      add :name, :string
      add :comment, :string
      add :exe_version, :integer
    end
    flush()
    create unique_index(:servers, [:login], name: :uk_server_login)
  end

  def down do
    drop table(:servers)
  end

end
