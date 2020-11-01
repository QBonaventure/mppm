defmodule Mppm.Track do
  use Ecto.Schema
  import Ecto.Query

  schema "tracks" do
    field :mx_track_id, :integer
    field :track_uid, :string
    field :name, :string
    field :gbx_map_name, :string
    field :author_login, :string
    field :author_id, :integer
    field :author_nickname, :string
    field :laps_nb, :integer
    field :awards_nb, :integer
    field :exe_ver, :string
    field :uploaded_at, :utc_datetime
    field :updated_at, :utc_datetime
    has_many :time_records, Mppm.TimeRecord
  end


  def track_from_mx(%{} = mx_track) do
    %Mppm.Track{
      mx_track_id: mx_track["TrackID"],
      track_uid: mx_track["TrackUID"],
      name: mx_track["Name"],
      gbx_map_name: mx_track["GbxMapName"],
      author_login: mx_track["AuthorLogin"],
      author_id: mx_track["UserID"],
      author_nickname: mx_track["Username"],
      laps_nb: mx_track["Laps"],
      awards_nb: mx_track["AwardCount"],
      exe_ver: mx_track["ExeVersion"],
      uploaded_at: get_dt(mx_track["UploadedAt"]),
      updated_at: get_dt(mx_track["UpdatedAt"])
    }
  end

  def get_by_uid(track_uid) when is_binary(track_uid), do:
    Mppm.Repo.get_by(Mppm.Track, track_uid: track_uid)
  def get_by_uid(tracks_uid) when is_list(tracks_uid), do:
    Mppm.Track |> where([t], t.track_uid in ^tracks_uid) |> Mppm.Repo.all

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
