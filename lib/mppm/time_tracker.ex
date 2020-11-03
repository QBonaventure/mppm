defmodule Mppm.TimeTracker do
  use GenServer

  @topic "waypoint-time"
  @time_topic "time-status"

  def add_track(state, track_uid, server_login) when is_binary(track_uid) do
    tracks = Map.get(state, :tracks)
    tracks =
      case Enum.find(tracks, & &1.track_uid == track_uid) do
        nil -> tracks ++ [Mppm.Track.get_by_uid(track_uid) |> Mppm.Repo.preload(:time_records)]
        _ -> tracks
      end
    servers_current_tracks = Map.put(state.servers_current_tracks, server_login, track_uid)
    %{tracks: tracks, servers_current_tracks: servers_current_tracks}
  end

  def remove_track(state, track_uid, server_login) do
    servers_current_tracks =
      Map.get(state, :servers_current_tracks)
      |> Map.put(server_login, nil)

    tracks =
      case Enum.any?(servers_current_tracks, & elem(&1, 1) == track_uid) do
        true -> state.tracks
        false -> Enum.reject(state.tracks, & &1.track_uid == track_uid)
      end
    %{tracks: tracks, servers_current_tracks: servers_current_tracks}
  end

  def is_new_record?(_, nil), do: true
  def is_new_record?(time, %Mppm.TimeRecord{lap_time: laptime}), do: time < laptime


  defp get_server_records(state, server_login) do
    track_uid = Map.get(state.servers_current_tracks, server_login)
    records =
      case Enum.find(state.tracks, & &1.track_uid == track_uid) do
        nil ->
          Mppm.Track.get_by_uid(track_uid) |> Mppm.Repo.preload(:time_records)
        track ->
          track
      end
      |> Map.get(:time_records)
  end

  def handle_call({:get_server_current_track, server_login}, _, state) do
    track_uid = Map.get(state.servers_current_tracks, server_login)
    {:reply, Mppm.Repo.get_by(Mppm.Track, track_uid: track_uid), state}
  end

  def handle_call({:get_server_records, server_login}, _, state), do:
    {:reply, get_server_records(state, server_login), state}

  def handle_info({%{"checkpointinrace" => 0, "login" => player_login, "racetime" => time}, server_login}, state) do
    {:noreply, Map.put(state, player_login, [time])}
  end

  def handle_info({%{"isendlap" => true, "login" => player_login, "racetime" => time}, server_login}, state) do
    user = Mppm.Repo.get_by(Mppm.User, login: player_login)
    track = GenServer.call({:global, {:mp_server, server_login}}, :get_current_track)

    case is_new_record?(time, Mppm.Repo.get_by(Mppm.TimeRecord, user_id: user.id, track_id: track.id)) do
      true ->
        new_time = Mppm.TimeRecord.insert_new_time(track, user, time, Map.get(state, player_login))
        updated_map =
          Enum.find(state.tracks, & &1.id == track.id)
          |> Mppm.Repo.preload(:time_records, force: true)
        tracks = Enum.reject(state.tracks, & &1.id == track.id) ++ [updated_map]

        Phoenix.PubSub.broadcast(Mppm.PubSub, @time_topic, {:new_time_record, server_login, new_time})

        {:noreply, %{state | tracks: tracks}}
      false ->
        {:noreply, state}
    end
  end

  def handle_info({%{"isendlap" => false, "login" => player_login, "racetime" => time}, server_login}, state) do
    {:noreply, Map.update!(state, player_login, & &1 ++ [time])}
  end

  def handle_info({id, server_login, track_uid}, state) when id in [:beginmap, :update_server_map] do
    state = add_track(state, track_uid, server_login)
    {:noreply, state}
  end

  def handle_info({:endmap, server_login, track_uid}, state) do
    {:noreply, remove_track(state, track_uid, server_login)}
  end

  def handle_info(_, state), do: {:noreply, state}


  def handle_cast({:track_server_time, server_login, track_uid}, state) do
    {:noreply, add_track(state, track_uid, server_login)}
  end

  def get_pubsub_topic(), do: @topic

  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def init(_) do
    state = %{tracks: [], servers_current_tracks: %{}, ongoing_runs: %{}}
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, @topic)
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "maps-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "players-status")
    {:ok, state}
  end

end
