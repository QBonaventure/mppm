defmodule Mppm.Service.ManiaExchange do
  alias Mppm.Service.ManiaExchange.Query
  use HTTPoison.Base
  alias HTTPoison.Response
  alias Mppm.Service.ManiaExchange.Track, as: MXTrack

  @mx_maps_info "https://trackmania.exchange/api/maps/get_map_info/multi/"
  @mx_track_search_uri "https://trackmania.exchange/mapsearch2/search"
  @download_track_url "https://trackmania.exchange/tracks/download/"

  @host "https://trackmania.exchange"


  def get_maps_info(maps_ids) when is_list(maps_ids) do
    maps_ids
    |> Enum.chunk_every(10)
    |> Enum.map(&make_maps_info_request(&1))
    |> List.flatten
  end


  def map_download_url(%Mppm.Service.ManiaExchange.Track{mx_track_id: track_id}),
    do: @download_track_url<> Integer.to_string(track_id)


  @spec make_maps_info_request([String.t()]) :: [MXTrack.t()]
  def make_maps_info_request(maps_ids) when is_list(maps_ids), do: maps_ids |> Enum.join(",") |> make_maps_info_request()
  def make_maps_info_request(map_id) when is_integer(map_id), do: Integer.to_string(map_id) |> make_maps_info_request()
  def make_maps_info_request(maps_ids) when is_binary(maps_ids) do
    {:ok, %Response{body: data}} = Mppm.Service.ManiaExchange.get("/api/maps/get_map_info/multi/" <> maps_ids)
    Enum.map(data, &MXTrack.cast(&1))
  end


  def make_request(%Query{} = query) do
    Mppm.Service.ManiaExchange.get("/mapsearch2/search", [], [params: query])
    |> parse
  end


  def process_url(url),
    do: @host <> url

  def process_request_headers(headers) do
    headers
    |> Keyword.put(:"Accept", "application/json")
  end

  def process_response_body(body) do
    case Jason.decode(body) do
      {:ok, data} -> data
    end
  end

  def process_request_options(options) do
    Enum.map(options, fn {key, value} ->
      case key do
        :params -> {:params, get_params(value)}
        _ -> {key, value}
      end
    end)
  end


  defp get_params(%Query{} = query) do
    %{
      api: "on",
      map_name: query.map_name,
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
