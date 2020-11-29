defmodule Mppm.TrackStyle do
  use Ecto.Schema

  schema "ref_track_styles" do
    field :name, :string
    # many_to_many :tracks, Mppm.Track, join_through: Mppm.TrackTag
    many_to_many :tracks, Mppm.Track, join_through: "rel_tracks_tags"
  end

end
