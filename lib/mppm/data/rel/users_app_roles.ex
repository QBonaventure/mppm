defmodule Mppm.Relationship.UsersAppRoles do
  use Ecto.Schema


  @primary_key false
  schema "rel_users_app_roles" do
    belongs_to :user, Mppm.User, primary_key: true
    belongs_to :user_app_role, Mppm.UserAppRole, primary_key: true
  end


end
