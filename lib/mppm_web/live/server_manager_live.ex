defmodule MppmWeb.ServerManagerLive do
  use Phoenix.LiveView


  def render(assigns) do
    MppmWeb.ServerManagerView.render("index.html", assigns)
  end

  def mount(params, _session, socket) do
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, Mppm.Broker.ReceiverServer.pubsub_topic(params["server_login"]))
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "players-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "tracklist-status")

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
      |> assign(tracklist: GenServer.call(Mppm.Tracklist, {:get_server_tracklist, server_config.login}))
      |> assign(mx_tracks_result: get_data())
      |> assign(current_track_status: :loading)
      |> assign(game_modes: Mppm.Repo.all(Mppm.Type.GameMode))
      |> assign(respawn_behaviours: Mppm.Repo.all(Mppm.Ruleset.RespawnBehaviour))
      |> assign(chat: Mppm.ChatMessage.get_last_chat_messages(server_config.id))
      |> assign(server_users: Mppm.ConnectedUsers.get_connected_users(server_config.login))
      |> assign(users: Mppm.Repo.all(Mppm.User) |> Mppm.Repo.preload(:roles))
      |> assign(available_roles: Mppm.Repo.all(Mppm.UserRole))

    {:ok, socket}
  end

  def broker_pname(server_login), do: {:global, {:broker_requester, server_login}}


  def handle_event("update-config", params, socket) do
    {:ok, changeset} = get_changeset(socket.assigns.server_info.id, params["server_config"])
    Mppm.ServerConfig.update(changeset)

    {:noreply, socket}
  end


  def handle_event("skip-map", _params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server_info.login), :skip_map)
    {:noreply, socket}
  end

  def handle_event("restart-map", _params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server_info.login), :restart_map)
    {:noreply, socket}
  end

  def handle_event("end-round", _params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server_info.login), :end_round)
    {:noreply, socket}
  end

  def handle_event("end-warmup", _params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server_info.login), :end_warmup)
    {:noreply, socket}
  end

  def handle_event("end-all-warmup", _params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server_info.login), :end_all_warmup)
    {:noreply, socket}
  end


  def handle_event("add-role", %{"user_id" => user_id, "role_id" => role_id}, socket) do
    {user_id, _} = Integer.parse(user_id)
    {role_id, _} = Integer.parse(role_id)

    {:ok, updated_user} =
      Enum.find(socket.assigns.users, & &1.id == user_id)
      |> Mppm.User.add_role(Enum.find(socket.assigns.available_roles, & &1.id == role_id))

    user_index = Enum.find_index(socket.assigns.users, & &1.id == user_id)

    {:noreply, assign(socket, users: List.replace_at(socket.assigns.users, user_index, updated_user))}
  end




  def handle_event("remove-role", %{"user-id" => user_id, "role-id" => role_id}, socket) do
    {user_id, _} = Integer.parse(user_id)
    {role_id, _} = Integer.parse(role_id)

    {:ok, updated_user} =
      Enum.find(socket.assigns.users, & &1.id == user_id)
      |> Mppm.User.remove_role(Enum.find(socket.assigns.available_roles, & &1.id == role_id))

    user_index = Enum.find_index(socket.assigns.users, & &1.id == user_id)

    {:noreply, assign(socket, users: List.replace_at(socket.assigns.users, user_index, updated_user))}
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

    Mppm.Tracklist
    |> GenServer.cast({:insert_track, socket.assigns.server_info.login, track, params["index"]-1})

    {:noreply, socket}
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

    GenServer.cast(Mppm.Tracklist, {:upsert_tracklist, socket.assigns.server_info.login, tracklist})
    {:noreply, assign(socket, tracklist: tracklist)}
  end

  def handle_event("update-tracklist", params, socket) do
    Mppm.Tracklist.upsert_tracklist(socket.assigns.tracklist)
    {:noreply, socket}
  end

  def handle_event("remove-track-from-list", params, socket) do
    {track_id, ""} = Integer.parse(Map.get(params, "track-id"))
    tracklist = Mppm.Tracklist.remove_track(socket.assigns.tracklist, track_id)
    GenServer.cast(Mppm.Tracklist, {:upsert_tracklist, socket.assigns.server_info.login, tracklist})
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




  def handle_info({:servers_users_updated, servers_users}, socket) do
    {:noreply, assign(socket, server_users: Map.get(servers_users, socket.assigns.server_info.login, []))}
  end

  def handle_info({:endmatch}, socket) do
    {:noreply, assign(socket, current_track_status: :ending)}
  end

  def handle_info({:endmap}, socket) do
    {:noreply, assign(socket, current_track_status: :unloading)}
  end

  def handle_info({:beginmap, %{"UId" => track_uid}}, socket) do
    {:noreply, assign(socket, current_track_status: :loading)}
  end

  def handle_info({:beginmatch}, socket) do
    {:noreply, assign(socket, current_track_status: :playing)}
  end


  def handle_info({:new_chat_message, %Mppm.ChatMessage{} = message}, socket) do
    {:noreply, assign(socket, chat: [message] ++ socket.assigns.chat)}
  end

  def handle_info({:tracklist_change, server_login, %Mppm.Tracklist{} = tracklist}, socket) do
    case server_login == socket.assigns.server_info.login do
      true -> {:noreply, assign(socket, tracklist: tracklist)}
      false -> {:noreply, socket}
    end
  end

  def handle_info(_unhandled_message, socket) do
    {:noreply, socket}
  end



  def handle_event("validate", params, socket) do
    {:ok, changeset} = get_changeset(socket.assigns.server_info.id, params["server_config"])
    {:noreply, assign(socket, changeset: changeset)}
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


def get_data(), do:
%{
  pagination: %{item_count: 0, items_per_page: 20, page: 1},
  tracks: []
}

end
