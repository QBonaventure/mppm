defmodule MppmWeb.ServerManagerLive do
  use Phoenix.LiveView


  def render(assigns) do
    MppmWeb.ServerManagerView.render("index.html", assigns)
  end

  def mount(params, session, socket) do
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, socket.id)
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, Mppm.Broker.ReceiverServer.pubsub_topic(params["server_login"]))
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "players-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "tracklist-status")

    server_config = Mppm.ServerConfig.get_server_config(params["server_login"])
    # TODO: implement the login system and actually select the right user

    user_session = Mppm.Session.AgentStore.get(session["current_user"])
    user = Mppm.Repo.get(Mppm.User, user_session.id)
    changeset = Ecto.Changeset.change(server_config)

    new_chat_message =
      %Mppm.ChatMessage{}
      |> Mppm.ChatMessage.changeset(user, server_config)

    socket =
      socket
      |> assign(mx_searchbox_tracklist: [])
      |> assign(user_session: session)
      |> assign(user: user)
      |> assign(new_chat_message: new_chat_message)
      |> assign(changeset: changeset)
      |> assign(server_info: server_config)
      |> assign(tracklist: GenServer.call(Mppm.Tracklist, {:get_server_tracklist, server_config.login}))
      |> assign(current_track_status: :loading)
      |> assign(game_modes: Mppm.Repo.all(Mppm.Type.GameMode))
      |> assign(respawn_behaviours: Mppm.Repo.all(Mppm.Ruleset.RespawnBehaviour))
      |> assign(chat: Mppm.ChatMessage.get_last_chat_messages(server_config.id))
      |> assign(users: get_users_lists(server_config.login))
      |> assign(available_roles: Mppm.Repo.all(Mppm.UserRole))

    {:ok, socket}
  end


  def get_users_lists(server_login) do
    connected_users_id =
      Mppm.ConnectedUsers.get_connected_users(server_login)
      |> Enum.map(& &1.id)

    Mppm.Repo.all(Mppm.User)
    |> Mppm.Repo.preload(:roles)
    |> Enum.map(fn user ->
      case user.id in connected_users_id do
        true -> Map.put(user, :is_connected?, true)
        false -> Map.put(user, :is_connected?, false)
      end
    end)
  end

  def broker_pname(server_login), do: {:global, {:broker_requester, server_login}}



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

  ################################################
  ################### EVENTS #####################
  ################################################


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

    {:ok, _updated_user} =
      Enum.find(socket.assigns.users, & &1.id == user_id)
      |> Mppm.User.add_role(Enum.find(socket.assigns.available_roles, & &1.id == role_id))

    {:noreply, assign(socket, users: get_users_lists(socket.assigns.server_info.login))}
  end


  def handle_event("remove-role", %{"user-id" => user_id, "role-id" => role_id}, socket) do
    {user_id, _} = Integer.parse(user_id)
    {role_id, _} = Integer.parse(role_id)

    {:ok, _updated_user} =
      Enum.find(socket.assigns.users, & &1.id == user_id)
      |> Mppm.User.remove_role(Enum.find(socket.assigns.available_roles, & &1.id == role_id))

    {:noreply, assign(socket, users: get_users_lists(socket.assigns.server_info.login))}
  end



  def handle_event("add-mx-track", params, socket) do
    {mx_track_id, ""} = params["data"] |> String.split("-") |> List.last |> Integer.parse
    track = Enum.find(socket.assigns.mx_searchbox_tracklist, & &1.mx_track_id == mx_track_id)

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

  def handle_event("update-tracklist", _params, socket) do
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


  def handle_event("validate", params, socket) do
    {:ok, changeset} = get_changeset(socket.assigns.server_info.id, params["server_config"])
    {:noreply, assign(socket, changeset: changeset)}
  end


  ################################################
  ################### INFOS ######################
  ################################################


  def handle_info({:mx_searchbox_tracklist, tracklist}, socket), do:
    {:noreply, assign(socket, mx_searchbox_tracklist: tracklist)}


  def handle_info({:servers_users_updated, server_login, _servers_users}, socket) do
    {:noreply, assign(socket, users: get_users_lists(server_login))}
  end

  def handle_info({:endmatch}, socket) do
    {:noreply, assign(socket, current_track_status: :ending)}
  end

  def handle_info({:endmap}, socket) do
    {:noreply, assign(socket, current_track_status: :unloading)}
  end

  def handle_info({:beginmap, %{"UId" => _track_uid}}, socket) do
    {:noreply, assign(socket, current_track_status: :loading)}
  end

  def handle_info({:beginmatch}, socket) do
    {:noreply, assign(socket, current_track_status: :playing)}
  end


  def handle_info({:new_chat_message, %Mppm.ChatMessage{} = message}, socket) do
    {:noreply, assign(socket, chat: [message] ++ socket.assigns.chat)}
  end

  def handle_info({:tracklist_update, server_login, %Mppm.Tracklist{} = tracklist}, socket) do
    case server_login == socket.assigns.server_info.login do
      true -> {:noreply, assign(socket, tracklist: tracklist)}
      false -> {:noreply, socket}
    end
  end

  def handle_info(_unhandled_message, socket) do
    {:noreply, socket}
  end


end
