defmodule Mppm.Repo.Migrations.AddUserTable do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :login, :string
      add :nickname, :string
      add :player_id, :integer
    end
  end
end
