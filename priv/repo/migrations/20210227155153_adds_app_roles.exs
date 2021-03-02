defmodule Mppm.Repo.Migrations.AddsAppRoles do
  use Ecto.Migration

  def up do
    create table(:ref_users_app_roles, primary_key: false) do
      add :id, :id, primary_key: true
      add :name, :string
    end

    create table(:rel_users_app_roles, primary_key: false) do
      add :user_id, references(:users), primary_key: true
      add :user_app_role_id, references(:ref_users_app_roles), primary_key: true
    end

    flush()

    insert_users_app_roles()
  end

  def down do
    drop table(:rel_users_app_roles)
    drop table(:ref_users_app_roles)
  end

  def insert_users_app_roles do
    Mppm.Repo.insert_all(
      Mppm.UserAppRole,
      [
        %{id: 1, name: "Administrator"},
        %{id: 2, name: "Operator"},
      ]
    )
  end

end
