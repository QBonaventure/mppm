defmodule Mppm.GameUI.TimePartialsDelta do
  use GenServer
  import Ecto.Query

  @background_style %{
    ahead: "background-positive",
    behind: "background-negative",
    equal: "background-quad-black"
  }


  def root_wrap(content \\ nil), do:
    {:manialink, [id: "time-partial-diffs", version: 3], [Mppm.GameUI.Stylesheet.get_stylesheet(), content]}

  def get_display(reference_time, user_time) do
    delta = user_time - reference_time
    {
      :frame,
      [id: "diffs", size: "36 4.5", pos: "-22 48"],
      [
        {:frame, [id: "diff-with-best", pos: "0 0", size: "36 4.5", halign: "left"], [
            {:label, [halign: "center", textsize: "2", pos: "9 -0.5", text: "Top 1"], []},
            {:label, [halign: "center", textsize: "2", pos: "27 -0.5", text: Mppm.TimeRecord.get_sign(delta)<> Mppm.TimeRecord.to_string(delta)], []},
            {:quad, [size: "18 4.5", pos: "9 0", halign: "center", class: "background-quad-black"], []},
            {:quad, [size: "18 4.5", pos: "27 0", halign: "center", class: Map.get(@background_style, Mppm.TimeRecord.compare(reference_time, user_time))], []}
        ]}
      ]
    }
    |> root_wrap
  end


  def handle_cast({:set_new_top_record, server_login, %Mppm.TimeRecord{} = new_time}, state) do
    {:noreply, Map.put(state, server_login, new_time)}
  end


  def handle_info({:loaded_map, server_login, track_uid}, state) do
    top_record = Mppm.Repo.one(
      from t in Mppm.TimeRecord,
      join: m in assoc(t, :track),
      where: m.track_uid == ^track_uid,
      order_by: {:asc, t.lap_time},
      limit: 1)

    {:noreply, Map.put(state, server_login, top_record)}
  end


  def handle_info({:new_time_record, server_login, time}, state) do
    case Mppm.TimeRecord.compare(time, Map.get(state, server_login)) do
      :ahead -> {:noreply, Map.put(state, server_login, time)}
      _ -> {:noreply, state}
    end
  end

  def handle_info({:player_waypoint, server_login, user_login, waypoint_nb, time}, state) do
    best_time =
      case Map.get(state, server_login, :no_key) do
        %Mppm.TimeRecord{} = best_time -> best_time
        :no_key ->
           best_time = GenServer.call(Mppm.TimeTracker, {:get_server_top_record, server_login})
           GenServer.cast(self(), {:set_new_top_record, server_login, best_time})
           best_time
        _ ->
          nil
      end

    if !is_nil(best_time) do
      best_time
      |> Map.get(:checkpoints)
      |> Enum.at(waypoint_nb)
      |> case do
        nil -> nil
        ref_time ->
          get_display(ref_time, time)
          |> Mppm.GameUI.Helper.send_to_user(server_login, user_login, 2000)
        end
    end

    {:noreply, state}
  end


  def handle_info(_, state) do
    {:noreply, state}
  end


  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def init(_) do
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "records-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "maps-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "time-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "race-status")
    {:ok, %{}}
  end

end
