defmodule Mppm.Track do
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  schema "tracks" do
    field :mx_track_id, :integer
    field :uuid, :string
    field :name, :string
    field :gbx_map_name, :string
    belongs_to :author, Mppm.User, foreign_key: :author_id
    belongs_to :style, Mppm.TrackStyle, foreign_key: :style_id
    many_to_many :tags, Mppm.TrackStyle, join_through: "rel_tracks_tags"
    field :laps_nb, :integer
    field :awards_nb, :integer
    field :exe_ver, :string
    field :uploaded_at, :utc_datetime
    field :updated_at, :utc_datetime
    field :is_deleted, :boolean, default: false
    has_many :time_records, Mppm.TimeRecord
    has_many :karma_votes, Mppm.TrackKarma
  end


  @required_fields ~w(mx_track_id uuid is_deleted name gbx_map_name laps_nb awards_nb exe_ver uploaded_at updated_at)a
  def changeset(%Mppm.Track{} = track, data \\ %{}) do
    track
    |> cast(data, @required_fields)
    |> put_assoc(:author, data.author)
    # |> put_assoc(:style, data.style)
    # |> put_assoc(:tags, data.tags)
  end


  def get_by_uid(uuid) when is_binary(uuid), do:
    Mppm.Repo.get_by(Mppm.Track, uuid: uuid)
  def get_by_uid(tracks_uid) when is_list(tracks_uid), do:
    Mppm.Track |> where([t], t.uuid in ^tracks_uid) |> Mppm.Repo.all


  def get_random_tracks(nb_of_tracks)
  when is_integer(nb_of_tracks) do
    query =
      from Mppm.Track,
      order_by: fragment("RANDOM()"),
      limit: ^nb_of_tracks
    Mppm.Repo.all(query)
  end


  def track_records(track_uuid, limit \\ 20) do
    Mppm.Repo.all(
      from t in Mppm.TimeRecord,
      select: t,
      join: tr in Mppm.Track, on: tr.uuid == ^track_uuid and tr.id == t.track_id,
      order_by: t.race_time,
      limit: ^limit
    )
  end

  def thumbnail_src(track_id) do
    "https://trackmania.exchange/maps/screenshot/normal/#{track_id}"
  end

end
