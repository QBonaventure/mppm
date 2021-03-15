defmodule Mppm.Service.ManiaExchange.Track do
  import Ecto.Query

  defstruct mx_track_id: nil,
    uuid: nil,
    name: nil,
    gbx_map_name: nil,
    author: nil,
    style: nil,
    tags: nil,
    laps_nb: nil,
    awards_nb: nil,
    exe_ver: nil,
    uploaded_at: nil, 
    updated_at: nil

  @spec cast(map()) :: {:ok, map()}
  def cast(%{} = mx_track) do
    style =
      case mx_track["StyleName"] do
        nil -> Mppm.Repo.get(Mppm.TrackStyle, 1)
        style_name -> Mppm.Repo.get_by(Mppm.TrackStyle, name: style_name)
      end
    tags =
      case mx_track["Tags"] do
        nil -> []
        tags_list_str ->
          tags_ids = String.split(tags_list_str, ",") |> Enum.map(& String.to_integer(&1))
          Mppm.Repo.all(from t in Mppm.TrackStyle, where: t.id in ^tags_ids)
      end

    %__MODULE__{
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

  defp get_dt(datetime) when is_binary(datetime) do
    {:ok, dt, _} = DateTime.from_iso8601(datetime<>"Z")
    DateTime.truncate(dt, :second)
  end

end
