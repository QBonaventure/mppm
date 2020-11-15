defmodule Mppm.User do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias __MODULE__

  schema "users" do
    field :login, :string
    field :nickname, :string
    field :player_id, :integer
    many_to_many :roles, Mppm.UserRole, [join_through: Mppm.Relationship.UsersRoles, on_replace: :delete]
  end

  def changeset(%User{} = message, data \\ []) do
    message
    |> cast(data, [:login, :nickname, :player_id])
  end


  def remove_role(%User{} = user, %Mppm.UserRole{} = role) do
    user = update_role(user, List.delete(user.roles, role))
    Phoenix.PubSub.broadcast("user-status", {:role_removed, user, role})
    user
  end

  def add_role(%User{} = user, %Mppm.UserRole{} = role) do
    user = update_role(user, [role | user.roles])
    Phoenix.PubSub.broadcast("user-status", {:role_granted, user, role})
    user
  end

  def update_role(%User{} = user, new_roles) do
    user
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:roles, new_roles)
    |> Mppm.Repo.update()
  end

end
