defmodule Mppm.Service.ManiaExchange.Track do
  @moduledoc """
  The returned map form MX is as follow
    %{
    "ReplayWRID" => nil,
    "ParserVersion" => 2,
    "HasThumbnail" => true,
    "ReplayCount" => 0,
    "Laps" => 1,
    "TrackValue" => 0,
    "EmbeddedObjectsCount" => 32,
    "IsMP4" => true,
    "RouteName" => "Single",
    "EnvironmentName" => "Stadium",
    "AuthorLogin" => "X-9AOE5jTY6Zw8saCSHSyQ",
    "HasScreenshot" => false,
    "TypeName" => "Race",
    "Lightmap" => 8,
    "Mood" => "NoStadium48x48Day",
    "GbxMapName" => "Tipping Point Route V1",
    "Name" => "Tipping Point Route V1",
    "MappackID" => 0,
    "RatingVoteAverage" => 0.0,
    "UserID" => 54607,
    "CommentCount" => 0,
    "HasGhostBlocks" => true,
    "UnlimiterRequired" => false,
    "Tags" => "36,39,50",
    "VehicleName" => "CarSnow",
    "EmbeddedItemsSize" => 2208488,
    "LengthName" => "45 secs",
    "Comments" => "For Ville map review",
    "AuthorCount" => 1,
    "ReplayWRUserID" => nil,
    "VideoCount" => 0,
    "Unlisted" => false,
    "TitlePack" => "TMStadium",
    "StyleName" => "SnowCar",
    "MapType" => "TM_Race",
    "ImageCount" => 0,
    "ReplayWRUsername" => nil,
    "Unreleased" => false,
    "DisplayCost" => 1767,
    "ModName" => "",
    "SizeWarning" => false,
    "ReplayWRTime" => nil,
    "AwardCount" => 0,
    "DifficultyName" => "Advanced",
    "ExeBuild" => "2024-07-02_14_35",
    "Downloadable" => true,
    "AuthorTime" => 37110,
    "UploadedAt" => "2024-09-07T16:54:19.063",
    "UpdatedAt" => "2024-09-07T16:54:19.063",
    ...
  }
  """
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
    updated_at: nil,
    is_deleted: false


  @doc """
  Casts data retrieved from the TrackmaniaExchange service as a map into a
  `Track` structure.
  """
  @spec cast(map()) :: {:ok, t::%__MODULE__{}}
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


  ##############################################################################
  ############################ Private Functions ###############################
  ##############################################################################

  defp get_dt(datetime) when is_binary(datetime) do
    {:ok, dt, _} = DateTime.from_iso8601(datetime<>"Z")
    DateTime.truncate(dt, :second)
  end

end
