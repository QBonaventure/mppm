defmodule Mppm.MXQuery do
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__

  @mx_maps_info "https://trackmania.exchange/api/maps/get_map_info/multi/"
  @mx_track_search_uri "https://trackmania.exchange/mapsearch2/search"
  @download_track_url "https://trackmania.exchange/tracks/download/"

  schema "mx_query_options" do
    field :author_name, :string
    belongs_to :track_style, Mppm.TrackStyle, foreign_key: :track_style_id
    field :map_name, :string, default: ""
    field :page, :integer, default: 1
    field :items_per_page, :integer, default: 20
  end

  def changeset(%Mppm.MXQuery{} = query, options \\ %{}) do
    query
    |> cast(options, [:author_name, :track_style_id, :map_name, :page])
  end


  def get_maps_info(maps_ids) when is_list(maps_ids) do
    maps_ids
    |> Enum.chunk_every(2)
    |> Enum.map(&make_maps_info_request(&1))
    |> List.flatten
  end

  def make_maps_info_request(maps_ids) when is_list(maps_ids), do: maps_ids |> Enum.join(",") |> make_maps_info_request()
  def make_maps_info_request(map_id) when is_integer(map_id), do: Integer.to_string(map_id) |> make_maps_info_request()
  def make_maps_info_request(maps_ids) when is_binary(maps_ids) do
    HTTPoison.request!(:get, @mx_maps_info <> maps_ids, "", [{"Accept", "application/json"}])
    |> Map.get(:body)
    |> Jason.decode!
    |> Enum.map(& Mppm.Track.track_from_mx(&1))
  end


  def make_request(%Mppm.MXQuery{} = query) do
    %HTTPoison.Request{
      method: :get,
      url: @mx_track_search_uri,
      headers: [{"Accept", "application/json"}],
      params: get_params(query)
    }
    |> HTTPoison.request
    |> parse
  end

  defp get_params(%Mppm.MXQuery{} = query) do
    %{
      api: "on",
      map_name: query.map_name,
      author: query.author_name,
      style: query.track_style_id,
      page: query.page,
      limit: query.items_per_page
    }
  end

  def parse({:ok, %HTTPoison.Response{} = response}), do: parse(response)

  def parse(%HTTPoison.Response{} = response) do
    body = response.body |> Jason.decode!

    tracks =
      body
      |> Map.get("results")
      |> Enum.map(& Mppm.Track.track_from_mx(&1))


    pagination = %{
      page: response.request.params.page,
      item_count: body |> Map.get("totalItemCount"),
      items_per_page:  response.request.params.limit
    }

    %{
      tracks: tracks,
      pagination: pagination
    }
  end

  ### May try using erlang's httpc to directly stream the binary into the file
  ### system and possibly save some memory usage out of it.
  def download_track(%Mppm.Track{mx_track_id: track_id}) do
    @download_track_url <> Integer.to_string(track_id)
    |> HTTPoison.get
  end

end
