defmodule Mppm.TimeTracker do
  use GenServer

  @topic "waypoint-time"
  @time_topic "time-status"

  def add_track(state, uuid, server_login) when is_binary(uuid) do
    tracks = Map.get(state, :tracks)
    tracks =
      case Enum.find(tracks, & &1.uuid == uuid) do
        nil -> tracks ++ [Mppm.Track.get_by_uid(uuid) |> Mppm.Repo.preload(:time_records)]
        _ -> tracks
      end
    servers_current_tracks = Map.put(state.servers_current_tracks, server_login, uuid)
    %{tracks: tracks, servers_current_tracks: servers_current_tracks}
  end

  def remove_track(state, uuid, server_login) do
    servers_current_tracks =
      Map.get(state, :servers_current_tracks)
      |> Map.put(server_login, nil)

    tracks =
      case Enum.any?(servers_current_tracks, & elem(&1, 1) == uuid) do
        true -> state.tracks
        false -> Enum.reject(state.tracks, & &1.uuid == uuid)
      end
    %{tracks: tracks, servers_current_tracks: servers_current_tracks}
  end

  defp is_new_record?(_, nil), do: true
  defp is_new_record?(time, %Mppm.TimeRecord{lap_time: laptime}), do: time < laptime


  defp get_server_records(state, server_login) do
    uuid = Map.get(state.servers_current_tracks, server_login)
    case Enum.find(state.tracks, & &1.uuid == uuid) do
      nil ->
        Mppm.Track.get_by_uid(uuid) |> Mppm.Repo.preload(:time_records)
      track ->
        track
    end
    |> Map.get(:time_records)
    |> Enum.sort_by(& &1.lap_time)
  end



  def handle_call({:get_server_top_record, server_login}, _, state), do:
    {:reply, get_server_records(state, server_login) |> Enum.sort_by(& &1.lap_time) |> List.first, state}


  def handle_call({:get_server_records, server_login}, _, state), do:
    {:reply, get_server_records(state, server_login), state}


  def handle_cast({:player_waypoint, _server_login, %{"checkpointinrace" => 0, "login" => player_login, "racetime" => time}}, state) do
    {:noreply, Map.put(state, player_login, [time])}
  end

  def handle_cast({:player_waypoint, server_login, %{"isendlap" => true, "login" => player_login, "racetime" => time}}, state) do
    user = Mppm.Repo.get_by(Mppm.User, login: player_login)
    {:ok, track} = Mppm.Tracklist.get_server_current_track(server_login)

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

  def handle_cast({:player_waypoint, _server_login, %{"isendlap" => false, "login" => player_login, "racetime" => time}}, state) do
    {:noreply, Map.update(state, player_login, [time], & &1 ++ [time])}
  end


  def handle_cast({:track_server_time, server_login, uuid}, state) do
    {:noreply, add_track(state, uuid, server_login)}
  end



  def handle_info({id, server_login, uuid}, state) when id in [:beginmap, :update_server_map] do
    state = add_track(state, uuid, server_login)
    {:noreply, state}
  end

  def handle_info({:endmap, server_login, uuid}, state) do
    {:noreply, remove_track(state, uuid, server_login)}
  end

  def handle_info(_, state), do: {:noreply, state}



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
