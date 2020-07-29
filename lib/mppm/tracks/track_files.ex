defmodule Mppm.TracksFiles do
  use GenServer

  @maps_path "/var/mppm/maps/"
  @mx_path "#{@maps_path}mx/"




  def handle_call({:update_server_tracks, tracklist}, _from, state) do

    {:noreply, state, state}
  end



  def get_files_list() do
    File.ls!(@mx_path)
    |> Enum.map(& {extract_mx_id(&1), &1})
    |> fetch_maps_data()
    # |> retrieve_missing_maps_data()
  end

  def extract_mx_id(filepath) do
    {id, _} =
      String.split(filepath)
      |> List.first()
      |> Integer.parse()
    id
  end

  def fetch_maps_data(maps_list) do
    maps_list
  end

  def retrieve_missing_maps_data(maps_list) do
    missing_maps_info =
      maps_list
      |> Enum.filter(fn {_, data} -> is_binary(data) end)
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

  def init(_init_value), do: {:ok, %{track_files: []}, {:continue, :check_files}}

  def handle_continue(:check_files, state) do

    {:noreply, state}
  end

end
