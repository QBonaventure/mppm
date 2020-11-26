defmodule MppmWeb.Live.Component.ManiaExchange do
  use Phoenix.LiveComponent


  def render(assigns) do
    MppmWeb.ManiaExchangeView.render("search_box.html", assigns )
  end

  def mount(socket) do
    mxo =
      %Mppm.Service.ManiaExchange.Query{}
      |> Mppm.Service.ManiaExchange.Query.changeset

    latest_awarded_maps =
      Mppm.Service.ManiaExchange.Query.latest_awarded_maps()
      |> Mppm.Service.ManiaExchange.make_request()

    Phoenix.PubSub.broadcast(Mppm.PubSub, socket.id, {:mx_searchbox_tracklist, latest_awarded_maps.tracks})

    socket =
      socket
      |> assign(mx_query_options: mxo)
      |> assign(track_style_options: Mppm.Repo.all(Mppm.TrackStyle))
      |> assign(mx_tracks_result: latest_awarded_maps)
    {:ok, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end


  def handle_call({:get_track, track_id}, _from, socket) do
    {:reply, Enum.find(socket.assigns.mx_tracks_results, & &1.mx_track_id == track_id), socket}
  end


  def handle_event("validate-mx-query", %{"query" => query}, socket) do
    {:noreply, assign(
      socket,
      mx_query_options: Mppm.Service.ManiaExchange.Query.changeset(socket.assigns.mx_query_options.data, query)
    )}
  end

  def handle_event("send-mx-request", %{"query" => query}, socket) do
    res =
      socket.assigns.mx_query_options.data
      |> Mppm.Service.ManiaExchange.Query.changeset(query)
      |> Ecto.Changeset.apply_changes()
      |> Mppm.Service.ManiaExchange.make_request()

    Phoenix.PubSub.broadcast(Mppm.PubSub, socket.id, {:mx_searchbox_tracklist, res.tracks})

    {:noreply, assign(socket, mx_tracks_result: res)}
  end


end
