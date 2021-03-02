defmodule Mppm.Relationship.UsersRoles do
  use Ecto.Schema


  @primary_key false
  schema "rel_users_roles" do
    belongs_to(:user, Mppm.User, primary_key: true)
    belongs_to(:user_role, Mppm.UserRole, primary_key: true)
  end

end
