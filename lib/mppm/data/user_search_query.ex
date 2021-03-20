defmodule Mppm.Users.SearchQuery do
  use Ecto.Schema
  import Ecto.Query

  schema "users_search_query" do
    field :username, :string
  end

  @type t() :: %__MODULE__{
    username: String.t()
  }

  @spec run(Mppm.Users.SearchQuery.t()) :: [Mppm.User.t()]
  def run(%__MODULE__{} = query) do
    Mppm.Repo.all(
      from u in Mppm.User,
      where: fragment("lower(?) like ?", u.nickname, ^format_term(query.username)),
      limit: 10
    )
  end

  defp format_term(term),
    do: "%#{term}%"

end
