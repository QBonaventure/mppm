defmodule Mppm.ChatMessage do
  use Ecto.Schema
  alias __MODULE__

  schema "chat_messages" do
    belongs_to :user, Mppm.User, foreign_key: :user_id
    belongs_to :server, Mpppm.ServerConfig, foreign_key: :server_id, define_field: false
    field :text, :string
  end

  def changeset(%ChatMessage{} = message, data \\ []) do
    message
    # |> cast(data, [:text])
  end

end
