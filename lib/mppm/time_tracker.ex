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
  end


  def ongoing_runs(server_login) do
    res = GenServer.call(__MODULE__, {:ongoing_runs, server_login})
    {:ok, res}
  end


  ##############################################################################
  ############################## GenServer Impl. ###############################
  ##############################################################################

  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def init(_) do
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "race-status")
    # :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "maps-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "players-status")

    {:ok, %{ongoing_runs: %{}, runs: %{}}}
  end


  def handle_call({:players_runs, _players_logins}, _from, state) do
    {:reply, state.ongoing_runs.server_login, state}
  end


  def handle_call({:ongoing_runs, server_login}, _from, state) do
    data =
      state.runs
      |> Enum.filter(fn {_user_login, data} -> data.server_login == server_login end)

    {:reply, data, state}
  end


  def handle_info({:user_disconnection, _server_login, user_login, _is_spectator?}, state) do
    ongoing_runs = Map.delete(state.ongoing_runs, user_login)
    runs = Map.delete(state.runs, user_login)

    {:noreply, %{state | ongoing_runs: ongoing_runs, runs: runs}}
  end

  def handle_info({event, server_login, user_login}, state)
  when event in [:player_start, :player_giveup] do
    ongoing_runs = Map.put(state.ongoing_runs, user_login, [])
    runs = Map.put(state.runs, user_login, %{server_login: server_login, partials: []})
    {:noreply, %{state | ongoing_runs: ongoing_runs, runs: runs}}
  end


  def handle_info({:player_waypoint, server_login, user_login, _waypoint_nb, time}, state) do
    player_cp_times = Map.get(state.ongoing_runs, user_login, []) ++ [time]
    ongoing_runs = Map.put(state.ongoing_runs, user_login, player_cp_times)
    runs = Map.put(state.runs, user_login, %{server_login: server_login, partials: player_cp_times})
    {:noreply, %{state | ongoing_runs: ongoing_runs, runs: runs}}
  end

  def handle_info({:player_end_race, server_login, user_login, _waypoint_nb, time}, state) do
    case new_time(server_login, user_login, time, Kernel.get_in(state, [:ongoing_runs, user_login])) do
      {:new, new_time} ->
        Mppm.PubSub.broadcast("race-status", {:new_time_record, server_login, new_time})
      :none ->
        nil
        # Map.get(state.tracks_records, track_uuid)
    end
    {:noreply, state}
  end


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
