defmodule Mppm.Repo.Migrations.AddUsersRoles do
  use Ecto.Migration

  def up do
    create table(:ref_users_roles, primary_key: false) do
      add :id, :id, primary_key: true
      add :name, :string
    end

    create table(:rel_users_roles, primary_key: false) do
      add :user_id, references(:users), primary_key: true
      add :user_role_id, references(:ref_users_roles), primary_key: true
    end

    flush()

    insert_user_roles()
  end

  def down do
    drop table(:rel_users_roles)
    drop table(:ref_users_roles)
  end

  def insert_user_roles do
    Mppm.Repo.insert_all(
      Mppm.UserRole,
      [
        %{id: 1, name: "Administrator"},
        %{id: 2, name: "Moderator"},
        %{id: 3, name: "Referee"},
        %{id: 4, name: "Member"},
      ]
    )
  end

end
