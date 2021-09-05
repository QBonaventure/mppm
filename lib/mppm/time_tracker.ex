defmodule Mppm.TimeTracker do
  use GenServer
  import Ecto.Query


  @moduledoc """
  Tracks, record and provide players best time on tracks.

  The state holds the map being played on each running server so that it can
  correctly manage cases where a map is being simultaneously played on different
  servers.
  """
  def top_record(%Mppm.Track{} = track) do
    res = Mppm.Repo.one(
      from r in Mppm.TimeRecord,
      join: t in assoc(r, :track),
      where: t.uuid == ^track.uuid,
      order_by: {:desc, r.race_time},
      limit: 1
    )
    case res do
      %Mppm.TimeRecord{} = rec -> {:ok, rec}
      nil -> {:ok, :none}
    end
  end
  def top_record(track_uuid) do
    Mppm.Repo.get_by(Mppm.Track, uuid: track_uuid)
    |> top_record()
  end

  def get_server_records(server_login) do
    {:ok, track} = Mppm.Tracklist.get_server_current_track(server_login)
    track_records(track.uuid)
    # case Enum.find(state.tracks, & &1.uuid == uuid) do
    #   nil ->
    #     Mppm.Track.get_by_uid(uuid) |> Mppm.Repo.preload(:time_records)
    #   track ->
    #     track
    # end
    # |> Map.get(:time_records)
    # |> Enum.sort_by(& &1.lap_time)
  end

  def get_ongoing_runs(server_login) do
    GenServer.call(__MODULE__, {:ongoing_runs, server_login})
  end


  ##############################################################################
  ############################## GenServer Impl. ###############################
  ##############################################################################

  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def init(_) do
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "race-status")
    # :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "maps-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "players-status")

    {:ok, %{ongoing_runs: %{}}}
  end


  # def handle_info({:started, server_login}, state) do
  #   {:ok, server_track} = Mppm.Tracklist.get_server_current_track(server_login)
  #   records = track_records(server_track.uuid)
  #   servers_track = Map.put(state.servers_track, server_login, server_track.uuid)
  #   tracks_records = Map.put(state.tracks_records, server_track.uuid, records)
  #
  #     {:noreply, %{state | servers_track: servers_track, tracks_records: tracks_records}}
  #   {:noreply, %{state | servers_track: servers_track, tracks_records: tracks_records}}
  # end

  # def handle_info({:stopped, server_login}, state) do
  #   track_uuid = Kernel.get_in(state, [:servers_track, server_login])
  #   servers_track = Map.delete(state.servers_track, server_login)
  #   tracks_records =
  #     case track_uuid in Map.values(servers_track) do
  #       true -> state.tracks_records
  #       false -> Map.delete(state.tracks_records, track_uuid)
  #     end
  #   {:noreply, %{state | tracks_records: tracks_records, servers_track: servers_track}}
  # end


  def handle_call({:ongoing_runs, server_login}, _from, state) do
    {:reply, state.ongoing_runs, state}
  end


  def handle_info({:user_disconnection, _server_login, user_login, _is_spectator?}, state) do
    {:noreply, %{state | ongoing_runs: Map.delete(state.ongoing_runs, user_login)}}
  end

  def handle_info({event, _server_login, user_login}, state)
  when event in [:player_start, :player_giveup] do
    runs = Map.put(state.ongoing_runs, user_login, [])
    {:noreply, %{state | ongoing_runs: runs}}
  end


  def handle_info({:player_waypoint, _server_login, user_login, _waypoint_nb, time}, state) do
    runs = Map.put(state.ongoing_runs, user_login, Map.get(state.ongoing_runs, user_login, []) ++ [time])
    {:noreply, %{state | ongoing_runs: runs}}
  end

  def handle_info({:player_end_race, server_login, user_login, _waypoint_nb, time}, state) do
    case new_time(server_login, user_login, time, Kernel.get_in(state, [:ongoing_runs, user_login])) do
      {:new, new_time} ->
        Mppm.PubSub.broadcast("race-status", {:new_time_record, server_login, new_time})
      :none ->
        # Map.get(state.tracks_records, track_uuid)
    end
    {:noreply, state}
  end


  # def handle_info({id, server_login, track_uuid}, state) when id in [:beginmap] do
  #   servers_track = Map.put(state.servers_track, server_login, track_uuid)
  #   track_records =
  #     case Map.has_key?(state.tracks_records, track_uuid) do
  #       true -> Map.get(state.tracks_records, track_uuid)
  #       false -> track_records(track_uuid)
  #     end
  #   state =
  #     state
  #     |> Kernel.put_in([:tracks_records, track_uuid], track_records)
  #     |> Kernel.put_in([:servers_track, server_login], track_uuid)
  #   {:noreply, state}
  # end

  # def handle_info({:endmap, server_login, track_uuid}, state) do
  #   servers_track = Map.delete(state.servers_track, server_login)
  #
  #   tracks_records =
  #     state.tracks_records
  #     |> Enum.filter(fn {track_uuid, _} -> track_uuid in Map.values(servers_track) end)
  #
  #   {:noreply, %{state | servers_track: servers_track, tracks_records: tracks_records}}
  # end

  def handle_info(_, state), do: {:noreply, state}


  ##############################################################################
  ############################# PRIVATE FUNCTIONS ##############################
  ##############################################################################


  defp new_time(server_login, user_login, time, waypoints_times) do
    user = Mppm.Repo.get_by(Mppm.User, login: user_login)
    {:ok, track} = Mppm.Tracklist.get_server_current_track(server_login)

    case is_new_record?(time, Mppm.Repo.get_by(Mppm.TimeRecord, user_id: user.id, track_id: track.id)) do
      true ->
        new_time = Mppm.TimeRecord.insert_new_time(track, user, time, waypoints_times)
        {:new, new_time}
      false ->
        :none
    end
  end

  defp is_new_record?(_, nil), do: true
  defp is_new_record?(time, %Mppm.TimeRecord{race_time: racetime}), do: time < racetime

  defp track_records(track_uuid) do
    Mppm.Repo.all(
      from t in Mppm.TimeRecord,
      select: t,
      join: tr in Mppm.Track, on: tr.uuid == ^track_uuid and tr.id == t.track_id,
      order_by: t.race_time
    )
  end

end
