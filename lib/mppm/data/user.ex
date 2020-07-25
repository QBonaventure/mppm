defmodule Mppm.User do
  use Ecto.Schema
  alias __MODULE__

  schema "users" do
    field :login, :string
    field :nickname, :string
    field :player_id, :string
  end

  def changeset(%User{} = message, data \\ []) do
    message
    # |> cast(data, [:text])
  end

end
