defmodule Mppm.User do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias __MODULE__

  schema "users" do
    field :login, :string
    field :nickname, :string
    field :uuid, Ecto.UUID, autogenerate: false
    many_to_many :roles, Mppm.UserRole, [join_through: Mppm.Relationship.UsersRoles, on_replace: :delete]
  end

  def changeset(%User{} = message, data \\ []) do
    message
    |> cast(data, [:login, :nickname, :uuid])
  end


  def remove_role(%User{} = user, %Mppm.UserRole{} = role) do
    user = update_role(user, List.delete(user.roles, role))
    Phoenix.PubSub.broadcast(Mppm.PubSub, "players-status", {:role_removed, elem(user, 1), role})
    user
  end

  def add_role(%User{} = user, %Mppm.UserRole{} = role) do
    user = update_role(user, [role | user.roles])
    Phoenix.PubSub.broadcast(Mppm.PubSub, "players-status", {:role_granted, elem(user, 1), role})
    user
  end

  def update_role(%User{} = user, new_roles) do
    user
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:roles, new_roles)
    |> Mppm.Repo.update()
  end

  def find(%Mppm.User{} = user) do
    case Mppm.Repo.one(from u in Mppm.User, where: u.uuid == ^user.uuid or u.nickname == ^user.nickname) do
      nil ->
        {:not_found, nil}
      found_user ->
        {:found, found_user}
    end
  end

end
