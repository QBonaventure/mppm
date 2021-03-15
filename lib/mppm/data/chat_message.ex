defmodule Mppm.ChatMessage do
  use Ecto.Schema
    import Ecto.Query
  import Ecto.Changeset
  alias __MODULE__

  schema "chat_messages" do
    belongs_to :user, Mppm.User, foreign_key: :user_id
    belongs_to :server, Mppm.GameServer.Server, foreign_key: :server_id
    field :text, :string
  end

  def changeset(%ChatMessage{} = message, user, server, data \\ %{}) do
    message
    |> cast(data, [:text])
    |> put_assoc(:user, user)
    |> put_assoc(:server, server)
    |> validate_required([:text, :server, :user])
  end

  def get_last_chat_messages(server_id) do
    query = from(
      m in Mppm.ChatMessage,
      where: m.server_id == ^server_id,
      order_by: [desc: m.inserted_at],
      limit: 20)
    Mppm.Repo.all(query) |> Mppm.Repo.preload(:user)
  end

end
