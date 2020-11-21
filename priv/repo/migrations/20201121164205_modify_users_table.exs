defmodule Mppm.Repo.Migrations.ModifyUsersTable do
  use Ecto.Migration

  def up do
    alter table(:users) do
      remove :player_id
      add :uuid, :uuid
    end

    create unique_index(:users, [:uuid])
  end

  def down do
    alter table(:users) do
      add :player_id, :integer
      remove :uuid
    end
  end

end
