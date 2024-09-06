defmodule MppmWeb.ServerWebpageLive do
  use Phoenix.LiveView


  def render(assigns) do
    MppmWeb.ServerWebpageView.render("index.html", assigns)
  end

  def mount(params, session, socket) do

    server_login = params["server_login"]
    if connected?(socket) do
      :ok = Mppm.PubSub.subscribe(socket.id)
      :ok = Mppm.PubSub.subscribe("race-status")
      :ok = Mppm.PubSub.subscribe("players-status")
    end

    # user_session = Mppm.Session.AgentStore.get(session["current_user"])
    {:ok, tracklist} = Mppm.Tracklist.get_tracklist(server_login)
    {:ok, time_data} = Mppm.TimeTracker.ongoing_runs(server_login)

    live_ranking =
      case time_data do
        [] ->
          %{}
        time_data ->
          Enum.map(time_data, fn {user_login, %{partials: partials}} ->
            {user_login, %{end?: false, waypoint_index: Enum.count(partials) , time: List.last(partials)}}
          end)
          |> Map.new()
      end

    socket =
      socket
      |> assign(tracklist: tracklist)
      |> assign(current_track_status: :playing)
      |> assign(user_session: session)
      |> assign(live_ranking: live_ranking)
    {:ok, socket}
  end


  def handle_info({:new_time_record, server_login, _new_time}, socket) do
    {:ok, track} = Mppm.Tracklist.get_server_current_track(server_login)
    send_update(MppmWeb.Live.Component.PublicTrackCard, id: track.id)
    {:noreply, socket}
  end


  def handle_info({event, _server_login, player_login, waypoint_index, time}, socket)
  when event in ~w(player_waypoint player_end_race)a do
    waypoint_index = waypoint_index+1
    end? = event == :player_end_race

    updated_live_ranking =
      socket.assigns.live_ranking
      |> Map.put(player_login, %{waypoint_index: waypoint_index, time: time, end?: end?})
      |> Enum.sort_by(fn {_login, %{time: time, waypoint_index: wp}} -> {1/wp, time} end)
      |> Map.new()

    {:noreply, assign(socket, live_ranking: updated_live_ranking)}
  end


  def handle_info({:player_giveup, _server_login, player_login}, socket) do
    updated_live_ranking =
      socket.assigns.live_ranking
      |> Map.delete(player_login)
    {:noreply, assign(socket, live_ranking: updated_live_ranking)}
  end


  def handle_info(_unhandled_message, socket) do
    {:noreply, socket}
  end

end
