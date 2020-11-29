defmodule Mppm.Repo.Migrations.AddUserTable do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :login, :string
      add :nickname, :string
      add :uuid, :uuid
    end
    create unique_index(:users, [:uuid], name: :uk_users_uuid)
    create unique_index(:users, [:login], name: :idx_users_login)
    create index(:users, [:nickname], name: :idx_users_nickname)
  end
end
