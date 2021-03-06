defmodule MppmWeb.AppSettingsLive do
  use Phoenix.LiveView

  def render(assigns) do
    MppmWeb.LayoutView.render("app_settings.html", assigns)
  end


  def mount(_params, session, socket) do
    Phoenix.PubSub.subscribe(Mppm.PubSub, "server-versions")
    server_versions = Mppm.GameServer.DedicatedServer.list_versions()
    socket =
      socket
      |> assign(user_session: session)
      |> assign(server_versions: server_versions)

    {:ok, socket}
  end

  def handle_info({:server_versions_update, versions}, socket) do
    {:noreply, assign(socket, server_versions: versions)}
  end

  def handle_params(%{}, uri, socket) do
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

  ##############################################################################
  ################################## MESSAGES ##################################
  ##############################################################################

  def handle_info({:status_updated, %Mppm.GameServer.DedicatedServer{} = dedi}, socket) do
    server_versions = Enum.map(socket.assigns.server_versions, fn serv_ver ->
      case serv_ver.version == dedi.version do
        true -> Map.put(serv_ver, :status, dedi.status)
        false -> serv_ver
      end
    end)
    {:noreply, assign(socket, server_versions: server_versions)}
  end

end
