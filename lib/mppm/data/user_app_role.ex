defmodule Mppm.UserAppRole do
  use Ecto.Schema
  import Ecto.Query

  schema "ref_users_app_roles" do
    field :name, :string
    many_to_many :users, Mppm.User, join_through: "rel_users_app_roles"
  end


  def app_roles() do
    Mppm.Repo.all(
      from u in Mppm.UserAppRole,
      inner_join: rel in assoc(u, :users)
      )
    |> Mppm.Repo.preload([:users])
  end

end
