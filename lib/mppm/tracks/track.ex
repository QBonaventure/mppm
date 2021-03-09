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
    has_many :time_records, Mppm.TimeRecord
  end


  @required_fields ~w(mx_track_id uuid name gbx_map_name laps_nb awards_nb exe_ver uploaded_at updated_at)a
  def changeset(%Mppm.Track{} = track, data \\ %{}) do
    track
    |> cast(data, @required_fields)
    |> put_assoc(:author, data.author)
    |> put_assoc(:style, data.style)
    |> put_assoc(:tags, data.tags)
  end


  @spec track_from_mx(map) :: %Mppm.Track{}
  def track_from_mx(%{} = mx_track) do
    style =
      case mx_track["StyleName"] do
        nil -> Mppm.Repo.get(Mppm.TrackStyle, 1)
        style_name -> Mppm.Repo.get_by(Mppm.TrackStyle, name: style_name)
      end
    tags =
      case mx_track["Tags"] do
        nil -> nil
        tags_list_str ->
          tags_ids = String.split(tags_list_str, ",") |> Enum.map(& String.to_integer(&1))
          Mppm.Repo.all(from t in Mppm.TrackStyle, where: t.id in ^tags_ids)
      end

    %Mppm.Track{
      mx_track_id: mx_track["TrackID"],
      uuid: mx_track["TrackUID"],
      name: mx_track["Name"],
      gbx_map_name: mx_track["GbxMapName"],
      author: mx_track["Username"],
      style: style,
      tags: tags,
      laps_nb: mx_track["Laps"],
      awards_nb: mx_track["AwardCount"],
      exe_ver: mx_track["ExeVersion"],
      uploaded_at: get_dt(mx_track["UploadedAt"]),
      updated_at: get_dt(mx_track["UpdatedAt"])
    }
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

  defp get_dt(datetime) when is_binary(datetime) do
    {:ok, dt, _} = DateTime.from_iso8601(datetime<>"Z")
    DateTime.truncate(dt, :second)
  end

end
