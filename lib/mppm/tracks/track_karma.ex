defmodule Mppm.TrackKarma do
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  @primary_key false
  schema "tracks_karma" do
    belongs_to :track, Mppm.Track, foreign_key: :track_id, primary_key: true
    belongs_to :user, Mppm.User, foreign_key: :user_id, primary_key: true
    field :note, :integer
  end

  @required_fields ~w(note)a
  def changeset(%Mppm.TrackKarma{} = track_karma, data \\ %{}) do
    track_karma
    |> cast(data, @required_fields)
    |> put_assoc(:track, data.track)
    |> put_assoc(:user, data.user)
  end

  def upsert_vote(%Mppm.User{} = user, %Mppm.Track{} = track, note) do
    %Mppm.TrackKarma{}
    |> Mppm.TrackKarma.changeset(%{user: user, track: track, note: note})
    |> Mppm.Repo.insert(on_conflict: :replace_all, conflict_target: [:user_id, :track_id])
  end

end
