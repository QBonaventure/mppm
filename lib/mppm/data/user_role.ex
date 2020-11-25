defmodule Mppm.UserRole do
  use Ecto.Schema

  schema "ref_users_roles" do
    field :name, :string
    many_to_many :users, Mppm.User, join_through: Mppm.Relationship.UsersRoles
  end

end
