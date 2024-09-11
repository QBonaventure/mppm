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

  def new(%Mppm.Track{} = track, %Mppm.User{} = user, note) do

    %Mppm.TrackKarma{track: track, user: user, note: note}
  end

end
