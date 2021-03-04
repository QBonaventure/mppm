defmodule Mppm.Repo.Migrations.AddsNotificationsTable do
  use Ecto.Migration

  def change do
    create table(:notifications) do
      add :type, :string
      add :message, :string
      add :created_at, :utc_datetime
    end
  end
end
