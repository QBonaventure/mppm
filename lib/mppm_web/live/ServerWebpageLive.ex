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
    {:ok, socket}
  end


  def handle_info({:new_time_record, server_login, _new_time}, socket) do
    {:ok, track} = Mppm.Tracklist.get_server_current_track(server_login)
    send_update(MppmWeb.Live.Component.PublicTrackCard, id: track.id)
    {:noreply, socket}
  end


  def handle_info(_unhandled_message, socket) do
    {:noreply, socket}
  end

end
