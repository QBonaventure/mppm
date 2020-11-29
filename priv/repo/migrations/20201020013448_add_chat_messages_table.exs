defmodule Mppm.Repo.Migrations.AddChatMessagesTable do
  use Ecto.Migration

  def change do
    create table(:chat_messages) do
      add :server_id, references(:servers_configs, on_delete: :delete_all)
      add :user_id, references(:users)
      add :text, :string
      add :inserted_at, :utc_datetime, default: fragment("NOW()")
    end
  end
end
