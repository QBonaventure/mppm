defmodule Mppm.ChatMessage do
  use Ecto.Schema
  use __MODULE__

  schema "chat_messages" do
    belongs_to :user, Mppm.User, foreign_key: id
    belongs_to :server, Mpppm.ServerConfig, foreign_key: :id, define_field: false
    field :text, :string
  end

  def changeset(%ChatMessage{} = message, data \\ [])
    message
    |> cast(data, [:text])
  end

end
