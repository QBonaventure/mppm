defmodule Mppm.UserAppRole do
  use Ecto.Schema

  schema "ref_users_app_roles" do
    field :name, :string
    many_to_many :users, Mppm.User, join_through: Mppm.Relationship.UsersAppRoles
  end

end
