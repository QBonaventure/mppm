defmodule Mppm.TimeTracker do
  use GenServer

  @topic "waypoint-time"
  @new_record_topic "new_time_record"


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


  def update_server_records_display(server_login, tracks, track_uid) do
    table =
      Enum.find(tracks, & &1.track_uid == track_uid)
      |> Map.get(:time_records)
      |> Mppm.Manialinks.TimeRecords.update_table()
    GenServer.call({:global, {:mp_broker, server_login}}, {:display, table, false, 0})
  end

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

        Phoenix.PubSub.broadcast(Mppm.PubSub, @new_record_topic, {:new_time_record, new_time})
        update_server_records_display(server_login, tracks, track.track_uid)

        {:noreply, %{state | tracks: tracks}}
      false ->
        {:noreply, state}
    end
  end

  def handle_info({%{"isendlap" => false, "login" => player_login, "racetime" => time}, server_login}, state) do
    {:noreply, Map.update!(state, player_login, & &1 ++ [time])}
  end


  def handle_info({:connection_to_server, server_login, player_login}, state) do
    IO.inspect "PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP"
    update_server_records_display(server_login, state.tracks, Map.get(state.servers_current_tracks, server_login))
    {:noreply, state}
  end

  def handle_info({id, server_login, track_uid}, state) when id in [:beginmap, :update_server_map] do
    state = Mppm.TimeTracker.add_track(state, track_uid, server_login)
    update_server_records_display(server_login, state.tracks, track_uid)
    {:noreply, state}
  end

  def handle_info({:endmap, server_login, track_uid}, state) do
    {:noreply, Mppm.TimeTracker.remove_track(state, track_uid, server_login)}
  end


  def handle_cast({:track_server_time, server_login, track_uid}, state) do
    Mppm.TimeTracker.add_track(state, track_uid, server_login)
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
