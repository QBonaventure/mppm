defmodule Mppm.Note do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field :type, :string
    field :message, :string
    field :created_at, :utc_datetime
  end

  def new(type, msg, %DateTime{} = datetime) when is_atom(type) and is_binary(msg) do
    %__MODULE__{type: type, message: msg, created_at: datetime}
  end

  def insert(%Mppm.Note{} = note) do
    note
    |> changeset()
    |> Mppm.Repo.insert!()
  end

  defp changeset(%Mppm.Note{} = note, params \\ %{}) do
    note
    |> Map.put(:type, Atom.to_string(note.type))
    |> cast(params, [:type, :message])
  end

end
