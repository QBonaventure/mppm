defmodule MppmWeb.ServerManagerLive do
  use Phoenix.LiveView
  alias Mppm.Repo

  def render(assigns) do
    # GenServer.call({:global, {:mp_broker, assigns.server_info.login}}, {:query, :get_current_map_info})
    MppmWeb.ServerManagerView.render("index.html", assigns)
  end

  def mount(params, _session, socket) do
    MppmWeb.Endpoint.subscribe(Mppm.Broker.ReceiverServer.pubsub_topic(params["server_login"]))

    server_config = Mppm.ServerConfig.get_server_config(params["server_login"])
    # TODO: implement the login system and actually select the right user
    user = Mppm.Repo.get(Mppm.User, 1)
    changeset = Ecto.Changeset.change(server_config)

    mxo =
      %Mppm.MXQuery{}
      |> Mppm.MXQuery.changeset

    new_chat_message =
      %Mppm.ChatMessage{}
      |> Mppm.ChatMessage.changeset(user, server_config)

    socket =
      socket
      |> assign(user: user)
      |> assign(new_chat_message: new_chat_message)
      |> assign(changeset: changeset)
      |> assign(server_info: server_config)
      |> assign(mx_query_options: mxo)
      |> assign(track_style_options: Mppm.Repo.all(Mppm.TrackStyle))
      |> assign(tracklist: Mppm.Tracklist.get_server_tracklist(server_config.login))
      |> assign(mx_tracks_result: get_data())
      |> assign(current_track_status: :loading)
      |> assign(game_modes: Mppm.Repo.all(Mppm.Type.GameMode))
      |> assign(respawn_behaviours: Mppm.Repo.all(Mppm.Ruleset.RespawnBehaviour))
      |> assign(chat: Mppm.ChatMessage.get_last_chat_messages(server_config.id))

        GenServer.call({:global, {:broker_requester, server_config.login}}, {:query, :get_current_map_info})

    {:ok, socket}
  end

  def broker_pname(server_login), do: {:global, {:broker_requester, server_login}}


  def handle_event("update-config", params, socket) do
    {:ok, changeset} = get_changeset(socket.assigns.server_info.id, params["server_config"])
    Mppm.ServerConfig.update(changeset)

    {:noreply, socket}
  end


  def handle_event("skip-map", params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server_info.login), :skip_map)
    {:noreply, socket}
  end

  def handle_event("restart-map", params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server_info.login), :restart_map)
    {:noreply, socket}
  end

  def handle_event("end-round", params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server_info.login), :end_round)
    {:noreply, socket}
  end

  def handle_event("end-warmup", params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server_info.login), :end_warmup)
    {:noreply, socket}
  end

  def handle_event("end-all-warmup", params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server_info.login), :end_all_warmup)
    {:noreply, socket}
  end





  def handle_event("validate-mx-query", params, socket) do
    {:noreply, assign(
      socket,
      mx_query_options: Mppm.MXQuery.changeset(socket.assigns.mx_query_options.data, params["mx_query"]
    ))}
  end

  def handle_event("send-mx-request", params, socket) do
    res =
      socket.assigns.mx_query_options.data
      |> Mppm.MXQuery.changeset(params["mx_query"])
      |> Ecto.Changeset.apply_changes
      |> Mppm.MXQuery.make_request

    {:noreply, assign(socket, mx_tracks_result: res)}
  end

  def handle_event("add-mx-track", params, socket) do
    {mx_track_id, ""} = params["data"] |> String.split("-") |> List.last |> Integer.parse
    track = get_mx_track_map(mx_track_id, socket.assigns.mx_tracks_result.tracks)

    tracklist = Mppm.Tracklist.add_track(socket.assigns.tracklist, track, params["index"]-1)
    save_tracklist_change(tracklist)
    {:noreply, assign(socket, tracklist: tracklist)}
  end

  def handle_event("reorganize-tracklist", params, socket) do
    {track_id, ""} =
      params["data"]
      |> String.replace_leading("track-", "")
      |> Integer.parse

    tracklist = socket.assigns.tracklist

    {track, tracks_collection} =
      tracklist.tracks
      |> List.pop_at(Enum.find_index(tracklist.tracks, & &1.id == track_id))


    tracklist = %{tracklist | tracks: List.insert_at(tracks_collection, params["index"], track)}

    save_tracklist_change(tracklist)
    {:noreply, assign(socket, tracklist: tracklist)}
  end

  def handle_event("update-tracklist", params, socket) do
    Mppm.Tracklist.upsert_tracklist(socket.assigns.tracklist)
    GenServer.call({:global, {:broker_requester, socket.assigns.server_info.login}}, :reload_match_settings)
    {:noreply, socket}
  end

  def handle_event("remove-track-from-list", params, socket) do
    {track_id, ""} = Integer.parse(Map.get(params, "track-id"))
    tracklist = Mppm.Tracklist.remove_track(socket.assigns.tracklist, track_id)
    save_tracklist_change(tracklist)
    {:noreply, assign(socket, tracklist: tracklist)}
  end


  def handle_event("validate-chat-message", %{"chat_message" => %{"text" => chat_msg}}, socket) do
    user = socket.assigns.user
    server = socket.assigns.server_info

    new_chat_msg =
      %Mppm.ChatMessage{}
      |> Mppm.ChatMessage.changeset(user, server, %{text: chat_msg})

    {:noreply, assign(socket, new_chat_message: new_chat_msg)}
  end

  def handle_event("send-chat-message", %{"chat_message" => %{"text" => chat_msg}}, socket) do
    message_to_send = "[" <> socket.assigns.user.nickname <> "] " <> chat_msg
    GenServer.call(broker_pname(socket.assigns.server_info.login), {:write_to_chat, message_to_send})

    {:noreply, socket}
  end




  def handle_info({:endmatch}, socket) do
    {:noreply, assign(socket, current_track_status: :ending)}
  end

  def handle_info({:endmap}, socket) do
    {:noreply, assign(socket, current_track_status: :unloading)}
  end

  def handle_info({:beginmap, %{"UId" => track_uid}}, socket) do
    tracklist = reorder_tracklist_from_cur_track(socket.assigns.tracklist, track_uid)
    {:noreply, assign(socket, tracklist: tracklist, current_track_status: :loading)}
  end

  def handle_info({:beginmatch}, socket) do
    {:noreply, assign(socket, current_track_status: :playing)}
  end

  def handle_info({:current_map_info, map_info}, socket) do
    tracklist = reorder_tracklist_from_cur_track(socket.assigns.tracklist, Map.get(map_info, "UId"))

    {:noreply, assign(socket, tracklist: tracklist, current_track_status: :playing)}
  end

  def handle_info({:new_chat_message, %Mppm.ChatMessage{} = message}, socket) do
    {:noreply, assign(socket, chat: [message] ++ socket.assigns.chat)}
  end


  def reorder_tracklist_from_cur_track(tracklist, track_uid) do
    cur_track_index =
      tracklist.tracks
      |> Enum.find_index(& &1.track_uid == track_uid)
    {to_last, to_first} = Enum.split(tracklist.tracks, cur_track_index)

    Map.put(tracklist, :tracks, to_first ++ to_last)
  end



  def handle_event("validate", params, socket) do
    {:ok, changeset} = get_changeset(socket.assigns.server_info.id, params["server_config"])
    {:noreply, assign(socket, changeset: changeset)}
  end


  def save_tracklist_change(%Mppm.Tracklist{} = tracklist) do
    tracklist = Mppm.Tracklist.upsert_tracklist(tracklist) |> Mppm.Repo.preload(:server)
    GenServer.call({:global, {:broker_requester, tracklist.server.login}}, :reload_match_settings)
  end

  def get_mx_track_map(mx_track_id, tracks_list) when is_integer(mx_track_id) do
    Enum.find(tracks_list, & &1.mx_track_id == mx_track_id)
  end

  def get_changeset(server_id, params) do
    changeset =
      Mppm.ServerConfig
      |> Mppm.Repo.get_by(%{id: server_id})
      |> Mppm.Repo.preload(ruleset: [:mode, :ta_respawn_behaviour, :rounds_respawn_behaviour])
      |> Mppm.ServerConfig.changeset(params)

    case Ecto.Changeset.apply_action(changeset, :update) do
      {:error, changeset} ->
        {:ok, changeset}
      {:ok, _ } ->
        {:ok, changeset}
    end
  end





defp get_dt(datetime) when is_binary(datetime) do
  {:ok, dt, _} = DateTime.from_iso8601(datetime<>"Z")
  DateTime.truncate(dt, :second)
end


def get_data(), do:
%{
  pagination: %{item_count: 0, items_per_page: 20, page: 1},
  tracks: []
}

end
