defmodule MppmWeb.ServerWebpageLive do
  use Phoenix.LiveView


  def render(assigns) do
    MppmWeb.ServerWebpageView.render("index.html", assigns)
  end

  def mount(params, session, socket) do
    if connected?(socket) do
      :ok = Mppm.PubSub.subscribe(socket.id)
      :ok = Mppm.PubSub.subscribe("race-status")
      :ok = Mppm.PubSub.subscribe("players-status")
    end

    user_session = Mppm.Session.AgentStore.get(session["current_user"])
    {:ok, tracklist} = Mppm.Tracklist.get_tracklist(params["server_login"])

    socket =
      socket
      |> assign(tracklist: tracklist)
      |> assign(current_track_status: :playing)
      |> assign(user_session: session)
      |> assign(live_ranking: %{})
    {:ok, socket}
  end


  def handle_info({:new_time_record, server_login, _new_time}, socket) do
    {:ok, track} = Mppm.Tracklist.get_server_current_track(server_login)
    send_update(MppmWeb.Live.Component.PublicTrackCard, id: track.id)
    {:noreply, socket}
  end

  def handle_info({event, server_login, player_login, waypoint_index, time} = pp, socket)
  when event in ~w(player_waypoint player_end_race)a do
    waypoint_index = waypoint_index+1
  end? = event == :player_end_race
    updated_live_ranking =
      socket.assigns.live_ranking
      |> Map.put(player_login, %{waypoint_index: waypoint_index, time: time, end?: end?})
      |> Enum.sort_by(fn {login, %{time: time, waypoint_index: wp}} -> {1/wp, time} end)
      |> Map.new()

    {:noreply, assign(socket, live_ranking: updated_live_ranking)}
  end

  def handle_info({:player_giveup, server_login, player_login}, socket) do
    updated_live_ranking =
      socket.assigns.live_ranking
      |> Map.delete(player_login)
    {:noreply, assign(socket, live_ranking: updated_live_ranking)}
  end


  def handle_info(unhandled_message, socket) do
    {:noreply, socket}
  end

end
