defmodule MppmWeb.ServerManagerLive do
  use Phoenix.LiveView


  def render(assigns) do
    MppmWeb.ServerManagerView.render("index.html", assigns)
  end

  def mount(params, session, socket) do
    {:ok, server} = Mppm.GameServer.Server.get_server(params["server_login"])

    :ok = Mppm.PubSub.subscribe(socket.id)
    :ok = Mppm.PubSub.subscribe(page_topic(params["server_login"]))
    :ok = Mppm.PubSub.subscribe("server-status")
    :ok = Mppm.PubSub.subscribe("players-status")
    :ok = Mppm.PubSub.subscribe("tracklist-status")

    user_session = Mppm.Session.AgentStore.get(session["current_user"])
    user = Mppm.Repo.get(Mppm.User, user_session.id)
    changeset = Ecto.Changeset.change(server)

    new_chat_message =
      %Mppm.ChatMessage{}
      |> Mppm.ChatMessage.changeset(user, server)

    {:ok, tracklist} = Mppm.Tracklist.get_tracklist(server.login)

    socket =
      socket
      |> assign(mx_searchbox_tracklist: [])
      |> assign(user_session: session)
      |> assign(user: user)
      |> assign(new_chat_message: new_chat_message)
      |> assign(changeset: changeset)
      |> assign(server: server)
      |> assign(tracklist: tracklist)
      |> assign(current_track_status: :playing)
      |> assign(game_modes: Mppm.Repo.all(Mppm.Type.GameMode))
      |> assign(respawn_behaviours: Mppm.Repo.all(Mppm.Ruleset.RespawnBehaviour))
      |> assign(chat: Mppm.ChatMessage.get_last_chat_messages(server.id))
      |> assign(users: get_users_lists(server.login))
      |> assign(available_roles: Mppm.Repo.all(Mppm.UserRole))

    {:ok, socket}
  end

  ################################################
  ################### EVENTS #####################
  ################################################


  def handle_event("cancel-form", _params, socket) do
    changeset = Ecto.Changeset.change(socket.assigns.server)
    {:noreply, assign(socket, changeset: changeset)}
  end


  def handle_event("validate", params, socket) do
    {:ok, changeset} = get_changeset(socket.assigns.server.id, params["server"])
    {:noreply, assign(socket, changeset: changeset)}
  end


  def handle_event("update-config", params, socket) do
    {:ok, changeset} = get_changeset(socket.assigns.server.id, params["server"])
    {:ok, new_server} = Mppm.GameServer.Server.update(changeset)

    {:noreply, assign(socket, changeset: Ecto.Changeset.change(new_server))}
  end


  def handle_event("skip-map", _params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server.login), :skip_map)
    {:noreply, socket}
  end


  def handle_event("restart-map", _params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server.login), :restart_map)
    {:noreply, socket}
  end


  def handle_event("end-round", _params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server.login), :end_round)
    {:noreply, socket}
  end


  def handle_event("end-warmup", _params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server.login), :end_warmup)
    {:noreply, socket}
  end


  def handle_event("end-all-warmup", _params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server.login), :end_all_warmup)
    {:noreply, socket}
  end


  def handle_event("add-role", %{"user_id" => user_id, "role_id" => role_id}, socket) do
    {user_id, _} = Integer.parse(user_id)
    {role_id, _} = Integer.parse(role_id)
    server = socket.assigns.server
    role = Enum.find(socket.assigns.available_roles, & &1.id == role_id)

    {:ok, _updated_user} =
      Enum.find(socket.assigns.users, & &1.id == user_id)
      |> Mppm.User.add_role(server, role)

    Mppm.PubSub.broadcast(page_topic(server.login), {:refresh_users})

    # {:noreply, assign(socket, users: get_users_lists(socket.assigns.server.login))}
    {:noreply, socket}
  end


  def handle_event("remove-role", %{"user-id" => user_id, "role-id" => role_id}, socket) do
    {user_id, _} = Integer.parse(user_id)
    {role_id, _} = Integer.parse(role_id)
    server = socket.assigns.server
    role = Enum.find(socket.assigns.available_roles, & &1.id == role_id)

    {:ok, _updated_user} =
      Enum.find(socket.assigns.users, & &1.id == user_id)
      |> Mppm.User.remove_role(server, role)

    Mppm.PubSub.broadcast(page_topic(server.login), {:refresh_users})

    {:noreply, assign(socket, users: get_users_lists(socket.assigns.server.login))}
    {:noreply, socket}
  end


  def handle_event("add-mx-track", params, socket) do
    tracklist = socket.assigns.tracklist
    {mx_track_id, ""} = params["data"] |> String.split("-") |> List.last |> Integer.parse
    index = params["index"]-1

    {:ok, track} =
      case Mppm.Repo.get_by(Mppm.Track, mx_track_id: mx_track_id) do
        nil ->
          mx_track = Enum.find(socket.assigns.mx_searchbox_tracklist, & &1.mx_track_id == mx_track_id)
          Mppm.TracksFiles.download_mx_track(mx_track)
        %Mppm.Track{} = track ->
          {:ok, track}
      end

    {_atom, _tracklist} = Mppm.Tracklist.add_track(tracklist, track, index)

    {:noreply, socket}
  end


  def handle_event("remove-track-from-list", params, socket) do
    {track_id, ""} = Integer.parse(Map.get(params, "track-id"))
    {:ok, tracklist} = Mppm.Tracklist.remove_track(socket.assigns.tracklist, track_id)
    {:noreply, assign(socket, tracklist: tracklist)}
  end


  def handle_event("reorganize-tracklist", params, socket) do
    {track_id, ""} =
      params["data"]
      |> String.replace_leading("track-", "")
      |> Integer.parse

    tracklist = socket.assigns.tracklist
    {:ok, tracklist} = Mppm.Tracklist.move_track_to(tracklist, track_id, params["index"])
    {:noreply, assign(socket, tracklist: tracklist)}
  end


  def handle_event("play-track", %{"track-id" => track_id}, socket) do
    {track_id, ""} = Integer.parse(track_id)
    {:ok, tracklist} = Mppm.Tracklist.reindex_for_next_track(socket.assigns.tracklist, track_id)

    GenServer.cast(broker_pname(socket.assigns.server.login), :skip_map)

    {:noreply, assign(socket, tracklist: tracklist)}
  end


  def handle_event("validate-chat-message", %{"chat_message" => %{"text" => chat_msg}}, socket) do
    user = socket.assigns.user
    server = socket.assigns.server

    new_chat_msg =
      %Mppm.ChatMessage{}
      |> Mppm.ChatMessage.changeset(user, server, %{text: chat_msg})

    {:noreply, assign(socket, new_chat_message: new_chat_msg)}
  end


  def handle_event("send-chat-message", %{"chat_message" => %{"text" => chat_msg}}, socket) do
    message_to_send = "[" <> socket.assigns.user.nickname <> "] " <> chat_msg
    GenServer.call(broker_pname(socket.assigns.server.login), {:write_to_chat, message_to_send})

    {:noreply, socket}
  end


  ################################################
  ################### INFOS ######################
  ################################################


  def handle_info({:refresh_users}, socket) do
    {:noreply, assign(socket, users: get_users_lists(socket.assigns.server.login))}
  end

  def handle_info({:test, changeset}, socket) do
    {:noreply, assign(socket, changeset: changeset)}
  end


  def handle_info({:mx_searchbox_tracklist, tracklist}, socket) do
    {:noreply, assign(socket, mx_searchbox_tracklist: tracklist)}
  end


  def handle_info({:servers_users_updated, server_login, _servers_users}, socket) do
    {:noreply, assign(socket, users: get_users_lists(server_login))}
  end

  def handle_info({:endmatch, server_login}, socket) do
    case socket.assigns.server.login == server_login do
      true -> {:noreply, assign(socket, current_track_status: :ending)}
      false -> {:noreply, socket}
    end
  end

  def handle_info({:endmap, server_login}, socket) do
    case socket.assigns.server.login == server_login do
      true -> {:noreply, assign(socket, current_track_status: :unloading)}
      false -> {:noreply, socket}
    end
  end

  def handle_info({:beginmap, server_login, %{"UId" => _uuid}}, socket) do
    case socket.assigns.server.login == server_login do
      true -> {:noreply, assign(socket, current_track_status: :loading)}
      false -> {:noreply, socket}
    end
  end

  def handle_info({:beginmatch, server_login}, socket) do
    case socket.assigns.server.login == server_login do
      true -> {:noreply, assign(socket, current_track_status: :playing)}
      false -> {:noreply, socket}
    end
  end


  def handle_info({:new_chat_message, %Mppm.ChatMessage{} = message}, socket) do
    {:noreply, assign(socket, chat: [message] ++ socket.assigns.chat)}
  end

  def handle_info({:tracklist_update, server_login, %Mppm.Tracklist{} = tracklist}, socket) do
    case server_login == socket.assigns.server.login do
      true -> {:noreply, assign(socket, tracklist: tracklist)}
      false -> {:noreply, socket}
    end
  end

  def handle_info(_unhandled_message, socket) do
    {:noreply, socket}
  end



  ##############################################################################
  ############################# PRIVATE FUNCTIONS ##############################
  ##############################################################################


  defp get_users_lists(server_login) do
    connected_users_id =
      Mppm.ConnectedUsers.get_connected_users(server_login)
      |> Enum.map(& &1.id)

    Mppm.Repo.all(Mppm.User)
    |> Mppm.Repo.preload([roles: [:user_role]])
    |> Enum.sort_by(& String.downcase(&1.nickname))
    |> Enum.map(fn user ->
      case user.id in connected_users_id do
        true -> Map.put(user, :is_connected?, true)
        false -> Map.put(user, :is_connected?, false)
      end
    end)
  end

  defp broker_pname(server_login), do: {:global, {:broker_requester, server_login}}



  defp get_changeset(server_id, params) do
    changeset =
      Mppm.GameServer.Server
      |> Mppm.Repo.get(server_id)
      |> Mppm.Repo.preload([:tracklist, :config, ruleset: [:mode, :ta_respawn_behaviour, :rounds_respawn_behaviour]])
      |> Mppm.GameServer.Server.changeset(params)

    case Ecto.Changeset.apply_action(changeset, :update) do
      {:error, changeset} ->
        {:ok, changeset}
      {:ok, _ } ->
        {:ok, changeset}
    end
  end


  defp page_topic(server_login),
    do: "server-manager:"<>server_login

end
