defmodule Mppm.Service.ManiaExchange do
  @moduledoc """
  Provider of the TrackmaniaExchange services. It allows querying info on tracks
  and searching for new ones.
  """

  use HTTPoison.Base

  alias Mppm.Service.ManiaExchange.Query
  alias HTTPoison.Response
  alias Mppm.Service.ManiaExchange.Track, as: MXTrack

  @host "https://trackmania.exchange"
  @mx_maps_info "/api/maps/get_map_info/multi/"
  @mx_track_search_uri "/mapsearch2/search"
  @download_track_url "https://trackmania.exchange/tracks/download/"


  @doc """
  Returns a list of `%Mppm.Service.ManiaExhange.Track{}` for each of the track
  ids provided in the list.
  """
  @spec get_maps_info([Integer.t(), ...]) :: %MXTrack{}
  def get_maps_info(maps_ids) when is_list(maps_ids) do
    maps_ids
    |> Enum.chunk_every(10)
    |> Enum.map(&make_maps_info_request(&1))
    |> List.flatten
  end

  @doc """
  Returns the url where a track can be found to download.
  """
  @spec map_download_url(%MXTrack{mx_track_id: integer}) :: String.t()
  def map_download_url(%MXTrack{mx_track_id: track_id}),
    do: @download_track_url <> Integer.to_string(track_id)


  @doc """
  Sends the `%Query{}` to the TrackmaniaExchange foreign service.

  Returns a list of `%MXTrack{}`.
  """
  @spec make_request(%Query{}) :: [%MXTrack{}, ...]
  def make_request(%Query{} = query) do
    Mppm.Service.ManiaExchange.get(@mx_track_search_uri , [], [params: query])
    |> parse
  end


  ##############################################################################
  ######################### HTTPoison implementation ###########################
  ##############################################################################

  @impl true
  def process_url(url),
    do: @host <> url

  @impl true
  def process_request_headers(headers) do
    headers
    |> Keyword.put(:"Accept", "application/json")
  end

  @impl true
  def process_response_body(body) do
    case Jason.decode(body) do
      {:ok, data} -> data
    end
  end

  @impl true
  def process_request_options(options) do
    Enum.map(options, fn {key, value} ->
      case key do
        :params -> {:params, get_params(value)}
        _ -> {key, value}
      end
    end)
  end


  ##############################################################################
  ############################ Private Functions ###############################
  ##############################################################################

  @spec make_maps_info_request([String.t()]) :: [MXTrack.t()]
  defp make_maps_info_request(maps_ids) when is_list(maps_ids), do:
    maps_ids |> Enum.join(",") |> make_maps_info_request()
  defp make_maps_info_request(map_id) when is_integer(map_id), do:
    Integer.to_string(map_id) |> make_maps_info_request()
  defp make_maps_info_request(maps_ids) when is_binary(maps_ids) do
    {:ok, %Response{body: data}} = Mppm.Service.ManiaExchange.get(@mx_maps_info <> maps_ids)
    Enum.map(data, &MXTrack.cast(&1))
  end


  defp get_params(%Query{} = query) do
    %{
      api: "on",
      trackname: query.map_name,
      author: query.author_name,
      style: query.track_style_id,
      page: query.page,
      limit: query.items_per_page
    }
  end


  defp parse({:ok, %HTTPoison.Response{} = response}), do: parse(response)
  defp parse(%HTTPoison.Response{body: body} = response) do
    tracks =
      body
      |> Map.get("results")
      |> Enum.map(& MXTrack.cast(&1))
    pagination = %{
      page: response.request.params.page,
      item_count: body |> Map.get("totalItemCount"),
      items_per_page:  response.request.params.limit
    }
    %{tracks: tracks, pagination: pagination}
  end


end
