defmodule Mppm.Repo.Migrations.AddServerConfigVersionColumn do
  use Ecto.Migration

  def change do
    alter table("servers_configs") do
      add :version, :integer
    end
  end
end
