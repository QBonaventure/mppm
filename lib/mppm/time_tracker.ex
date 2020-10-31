defmodule Mppm.TimeTracker do
  use GenServer

  @topic "waypoint-time"
  @new_record_topic "new_time_record"


  def is_new_record?(_, nil), do: true
  def is_new_record?(time, %Mppm.TimeRecord{lap_time: laptime}), do: time < laptime


  def handle_info({%{"checkpointinrace" => 0, "login" => player_login, "racetime" => time}, server_login}, state) do
    {:noreply, Map.put(state, player_login, [time])}
  end


  def handle_info({%{"isendlap" => true, "login" => player_login, "racetime" => time}, server_login}, state) do
    user = Mppm.Repo.get_by(Mppm.User, login: player_login)
    track = GenServer.call({:global, {:mp_server, server_login}}, :get_current_track)

    if is_new_record?(time, Mppm.Repo.get_by(Mppm.TimeRecord, user_id: user.id, track_id: track.id)) do
      params =
        %{
          checkpoints: Map.get(state, player_login),
          race_time: time,
          lap_time: time,
          track_id: track.id,
          user_id: user.id
        }
      new_time =
        %Mppm.TimeRecord{}
        |> Mppm.TimeRecord.changeset(params)
        |> Mppm.Repo.insert!(on_conflict: {:replace_all_except, [:user_id, :track_id]}, conflict_target: [:user_id, :track_id])
        |> IO.inspect
      Phoenix.PubSub.broadcast(Mppm.PubSub, @new_record_topic, {:new_time_record, new_time})
    end

    {:noreply, state}
  end

  def handle_info({%{"isendlap" => false, "login" => player_login, "racetime" => time}, server_login}, state) do
    {:noreply, Map.update!(state, player_login, & &1 ++ [time])}
  end


  def get_pubsub_topic(), do: @topic

  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def init(_) do
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, @topic)
    {:ok, %{}}
  end

end
