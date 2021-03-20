defmodule MppmWeb.AppSettingsLive do
  use Phoenix.LiveView

  def render(assigns) do
    MppmWeb.LayoutView.render("app_settings.html", assigns)
  end


  def mount(_params, session, socket) do
    Phoenix.PubSub.subscribe(Mppm.PubSub, "server-versions")
    Phoenix.PubSub.subscribe(Mppm.PubSub, "user-status")
    server_versions = Mppm.GameServer.DedicatedServer.list_versions()
    app_roles = Mppm.Repo.all(Mppm.UserAppRole)

    socket =
      socket
      |> assign(user_session: session)
      |> assign(server_versions: server_versions)
      |> assign(app_roles: app_roles)
      |> assign(roles: Mppm.UserAppRole.app_roles())

    {:ok, socket}
  end


  def handle_params(%{}, _uri, socket) do
    {:noreply, socket}
  end



  ##############################################################################
  ################################### EVENTS ###################################
  ##############################################################################


  def handle_event("install-server", %{"version" => version}, socket) do
    Mppm.GameServer.DedicatedServer.install_game_server(String.to_integer(version))
    {:noreply, socket}
  end


  def handle_event("uninstall-server", %{"version" => version}, socket) do
    Mppm.GameServer.DedicatedServer.uninstall_game_server(String.to_integer(version))
    {:noreply, socket}
  end


  def handle_event("element-dropped", %{"element_id" => element_id, "target" => target}, socket)
  when target in ["administrators-list", "operators-list"] do
    role =
      case target do
        "administrators-list" -> Enum.find(socket.assigns.app_roles, & &1.name == "Administrator")
        "operators-list" -> Enum.find(socket.assigns.app_roles, & &1.name == "Operator")
      end

      user_id =
        element_id
        |> String.split("-")
        |> List.last()
        |> String.to_integer()

    case Mppm.User |> Mppm.Repo.get(user_id) |> Mppm.User.update_app_role(role) do
      {:ok, user} ->
        Mppm.PubSub.broadcast("user-status", {:app_role_updated, user, role})
        {:noreply, socket}
      {:error, _changeset} ->
        {:noreply, socket}
    end
  end


  def handle_event("element-dropped", %{"element_id" => element_id, "target" => "remove-role-of-user"}, socket) do
    user_id =
      element_id
      |> String.split("-")
      |> List.last()
      |> String.to_integer()
    case Mppm.User |> Mppm.Repo.get(user_id) |> Mppm.User.update_app_role([]) do
      {:ok, user} ->
        Mppm.PubSub.broadcast("user-status", {:app_role_updated, user, nil})
        {:noreply, socket}
      {:error, _changeset} ->
        {:noreply, socket}
    end
  end


  ##############################################################################
  ################################## MESSAGES ##################################
  ##############################################################################

  def handle_info({:server_versions_update, versions}, socket) do
    {:noreply, assign(socket, server_versions: versions)}
  end


  def handle_info({:status_updated, %Mppm.GameServer.DedicatedServer{} = dedi}, socket) do
    server_versions = Enum.map(socket.assigns.server_versions, fn serv_ver ->
      case serv_ver.version == dedi.version do
        true -> Map.put(serv_ver, :status, dedi.status)
        false -> serv_ver
      end
    end)
    {:noreply, assign(socket, server_versions: server_versions)}
  end

  def handle_info({:app_role_updated, _user, _role}, socket) do
    socket =
      socket
      |> assign(app_roles: Mppm.Repo.all(Mppm.UserAppRole))
      |> assign(roles: Mppm.UserAppRole.app_roles())
    {:noreply, socket}
  end


  ##############################################################################
  ############################# PRIVATE FUNCTIONS ##############################
  ##############################################################################


end
