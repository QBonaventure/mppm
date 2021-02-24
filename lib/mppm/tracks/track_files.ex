defmodule Mppm.TracksFiles do
  use GenServer

  @maps_path Application.get_env(:mppm, :game_servers_root_path) <> "UserData/Maps/"
  @mx_directory "MX/"
  @mx_path "#{@maps_path}#{@mx_directory}"

  @header_start <<60, 104, 101, 97, 100, 101, 114>>
  @header_end <<60, 47, 104, 101, 97, 100, 101, 114, 62>>

  def mx_path(), do: @mx_path


  def handle_call(:get_tracks, _from, state) do
    {:reply, state.tracks_files, state}
  end


  def handle_call({:update_server_tracks, _tracklist}, _from, state) do
    {:noreply, state, state}
  end


  def extract_track_file_data(path) do
    File.stream!(path)
    |> Stream.with_index
    |> Stream.filter(fn {value, index} ->
      String.chunk(value, :printable)
      |> Enum.find(& String.starts_with?(&1, @header_start))
     end)
    |> Enum.at(0)
    |> elem(0)
    |> String.chunk(:printable)
    |> Enum.find(& String.starts_with?(&1, "<header"))
    |> Mppm.XML.track_xml_to_map()
  end


  def download_mx_track(%Mppm.Track{mx_track_id: _track_id} = track) do
    track_file_path = @maps_path <> mx_track_path(track)
    case Mppm.Service.ManiaExchange.download_track(track) do
      {:ok, http_resp} ->
          track_file_path |> File.write(http_resp.body)
          file_data = extract_track_file_data(track_file_path)
          user = Mppm.User.get(%Mppm.User{login: file_data.author})

          track =
            track
            |> Map.put(:author, user)
            |> Mppm.Repo.insert(on_conflict: {:replace_all_except, [:id]}, conflict_target: :uuid)
          # track_data =

      _ -> {:error, :download_failed}
    end
  end


  def mx_track_path(%Mppm.Track{mx_track_id: track_id, name: track_name}), do:
    "#{@mx_directory}#{track_id}_#{Slug.slugify(track_name)}.Map.Gbx"



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
      |> Mppm.Service.ManiaExchange.get_maps_info()

    Enum.map(maps_list, fn map ->
      case map do
        {id, map_filename} ->
          file_data = extract_track_file_data(@mx_path<>map_filename)
          user = Mppm.User.get(%Mppm.User{login: file_data.author})
          data =
            Enum.find(missing_maps_info, & &1.mx_track_id == id)
            |> Map.from_struct()
            |> Map.put(:author, user)
          %Mppm.Track{}
          |> Mppm.Track.changeset(data)
          |> Mppm.Repo.insert!
        _ -> map
      end
    end)
  end



  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def init(_init_value), do: {:ok, %{tracks_files: []}, {:continue, :check_files}}

  def handle_continue(:check_files, state), do: {:noreply, %{state | tracks_files: get_files_list()}}

end
