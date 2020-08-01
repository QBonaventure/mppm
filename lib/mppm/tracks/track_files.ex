defmodule Mppm.TracksFiles do
  use GenServer

  @maps_path "/var/mppm/maps/"
  @mx_path "#{@maps_path}mx/"


  def handle_call(:get_tracks, _from, state) do
    {:reply, state.tracks_files, state}
  end


  def handle_call({:update_server_tracks, tracklist}, _from, state) do

    {:noreply, state, state}
  end



  def download_mx_track(%Mppm.Track{mx_track_id: track_id} = track) do
    case Mppm.MXQuery.download_track(track_id) do
      {:ok, track_binary} -> mx_track_path(track) |> File.write(track_binary)
      _ -> {:error, :download_failed}
    end
  end


  def mx_track_path(%Mppm.Track{mx_track_id: track_id, name: track_name}), do:
    "#{@maps_path}MX/#{track_id}_#{Slug.slugify(track_name)}.Map.Gbx"



  def get_files_list() do
    File.ls!(@mx_path)
    |> Enum.map(& {extract_mx_id(&1), &1})
    |> fetch_maps_data()
    |> retrieve_missing_maps_data()
  end

  def extract_mx_id(filepath) do
    {id, _} =
      String.split(filepath)
      |> List.first()
      |> Integer.parse()
    id
  end

  def fetch_maps_data(maps_list) do
    records = Mppm.Repo.all(Mppm.Track)

    maps_list
    |> Enum.map(fn {id, _} = track -> Enum.find(records, track, & &1.mx_track_id == id) end)
  end

  def retrieve_missing_maps_data(maps_list) do
    missing_maps_info =
      maps_list
      |> Enum.filter(fn track -> not is_map(track)  end)
      |> Enum.map(fn {id, _} -> id end)
      |> Mppm.MXQuery.get_maps_info()

    Enum.map(maps_list, fn map ->
      case map do
        {id, _} ->
          Enum.find(missing_maps_info, & &1.mx_track_id == id)
          |> Mppm.Repo.insert!
        _ -> map
      end
    end)
  end



  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def init(_init_value), do: {:ok, %{tracks_files: []}, {:continue, :check_files}}

  def handle_continue(:check_files, state), do: {:noreply, %{state | tracks_files: get_files_list()}}

end
