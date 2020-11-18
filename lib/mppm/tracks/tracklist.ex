defmodule Mppm.Tracklist do
  use GenServer
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset


  @primary_key {:server_id, :id, autogenerate: false}
  schema "tracklists"  do
    belongs_to :server, Mppm.ServerConfig, foreign_key: :server_id, primary_key: true, define_field: false
    field :tracks_ids, {:array, :integer}, default: []
    field :tracks, {:array, %Mppm.Track{}}, default: [], virtual: true
  end


  def changeset(%Mppm.Tracklist{} = tracklist, params \\ %{} ) do
    tracklist
    |> cast(params, [:tracks_ids, :server_id, :tracks])
    |> cast_assoc(:server)
  end


  def upsert_tracklist(%Mppm.Tracklist{} = tracklist) do
    mx_tracks_ids = Enum.map(tracklist.tracks, & Map.get(&1, :mx_track_id))
    tracks = Mppm.Repo.all(from t in Mppm.Track, where: t.mx_track_id in ^mx_tracks_ids)

    mxds =
      mx_tracks_ids
      |> Enum.map(fn mx_id ->
        Enum.find(tracks, mx_id, fn track_struct -> track_struct.mx_track_id == mx_id end)
      end)
      |> Enum.map(fn track ->
        case track do
          %Mppm.Track{} ->
            track
          mx_id when is_integer(mx_id) ->
            Mppm.TracksFiles.download_mx_track(Enum.find(tracklist.tracks, & &1.mx_track_id == mx_id))
        end
      end)
      |> Enum.map(& &1.id)


    {:ok, tracklist} =
      %{tracklist | tracks_ids: mxds}
      |> Mppm.Repo.preload(:server)
      |> Mppm.Repo.insert(on_conflict: [set: [tracks_ids: mxds]], conflict_target: :server_id)

    Phoenix.PubSub.broadcast(Mppm.PubSub, "tracklist-state", {:tracklist_update, tracklist})
    Mppm.ServerConfig.create_tracklist(tracklist)
    tracklist
  end


  def add_track(%Mppm.Tracklist{} = tracklist, %Mppm.Track{} = track, index) do
    track =
      case File.exists?(Mppm.TracksFiles.mx_track_path(track)) do
        false -> {:ok, track} =
          Mppm.TracksFiles.download_mx_track(track)
          track
        true -> track
      end
    %{tracklist | tracks: List.insert_at(tracklist.tracks, index, track)}
  end

  def remove_track(%Mppm.Tracklist{} = tracklist, track_id) when is_integer(track_id) do
    %{tracklist | tracks: Enum.reject(tracklist.tracks, & &1.id == track_id)}
  end


  def load_ordered_tracks(%Mppm.Tracklist{tracks_ids: []} = tracklist), do: tracklist
  def load_ordered_tracks(%Mppm.Tracklist{tracks_ids: tracks_ids} = tracklist) do
    Map.put(tracklist, :tracks, from(t in Mppm.Track,
      where: t.id in ^tracks_ids,
      order_by: fragment("array_position(?,?)", ^tracks_ids, t.id)
      )
      |> Mppm.Repo.all
    )
  end

  def handle_call({:get_server_current_track, server_login}, _from, state) do
    track = Map.get(state, server_login) |> Map.get(:tracks) |> List.first()
    {:reply, track, state}
  end

  def handle_call({:get_server_next_track, server_login}, _from, state) do
    tracks = Map.get(state, server_login) |> Map.get(:tracks)
    {:reply, Enum.at(tracks, 1, List.first(tracks)), state}
  end

  def handle_call({:get_server_tracklist, server_login}, _from, state) do
    {:reply, Map.get(state, server_login), state}
  end



  def handle_cast({:insert_track, server_login, %Mppm.Track{} = track, index}, state) do
    tracklist = Map.get(state, server_login) |> add_track(track, index)
    Mppm.Tracklist.upsert_tracklist(tracklist)
    Phoenix.PubSub.broadcast(Mppm.PubSub, "tracklist-status", {:tracklist_change, server_login, tracklist})
    {:noreply, %{state | server_login => tracklist}}
  end

  def handle_cast({:upsert_tracklist, server_login, tracklist}, state) do
    tracklist = Mppm.Tracklist.upsert_tracklist(tracklist) |> Mppm.Repo.preload(:server)
    Phoenix.PubSub.broadcast(Mppm.PubSub, "tracklist-status", {:tracklist_change, server_login, tracklist})
    {:noreply, %{state | server_login => tracklist}}
  end


  def handle_info({_message, server_login, track_uid}, state)
  when _message in [:current_track_info, :loaded_map] do
    tracklist = reindex_from_current_track(Map.get(state, server_login), track_uid)
    Phoenix.PubSub.broadcast(Mppm.PubSub, "tracklist-status", {:tracklist_change, server_login, tracklist})
    Mppm.ServerConfig.create_tracklist(tracklist)
    {:noreply, %{state | server_login => tracklist}}
  end

  def reindex_from_current_track(%Mppm.Tracklist{} = tracklist, track_uid) do
    tracks = Map.get(tracklist, :tracks)
    cur_track_index = tracks |> Enum.find_index(& &1.track_uid == track_uid)
    {to_last, to_first} = Enum.split(tracks, cur_track_index)

    Map.put(tracklist, :tracks, to_first ++ to_last)
  end

  def handle_info(_unhandled_message, state) do
    {:noreply, state}
  end


  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def init(_init_value) do
    Phoenix.PubSub.subscribe(Mppm.PubSub, "maps-status")
    state = fetch_all_tracklists()
    # {:ok, state, {:continue, :check_files}}
    {:ok, state}
  end


  defp fetch_all_tracklists() do
    tracklists = Mppm.Repo.all(
      from tl in Mppm.Tracklist,
      join: sc in Mppm.ServerConfig, on: tl.server_id == sc.id,
      select: {sc.login, tl}
    )
    |> Enum.map(fn {server_login, tracklist} ->
      {server_login, Map.put(
        tracklist,
        :tracks,
        Mppm.Repo.all(
          from t in Mppm.Track,
          where: t.id == fragment("ANY(?)", ^tracklist.tracks_ids),
          order_by: fragment("array_position(?, ?)", ^tracklist.tracks_ids, t.id)
        )
      )}
    end)
    |> Map.new
  end
end
