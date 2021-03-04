defmodule MppmWeb.Live.Component.ServerLine do
  use Phoenix.LiveComponent
  alias MppmWeb.DashboardView

  def mount(socket) do
    servers_versions =
      Mppm.GameServer.DedicatedServer.ready_to_use_servers()
    socket =
      socket
      |> assign(servers_versions: servers_versions)
    {:ok, socket}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(server: assigns.server)
      |> assign(version_changeset: Mppm.ServerConfig.changeset(assigns.server.config))
    {:ok, socket}
  end

  def render(assigns) do
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "server-status:"<>assigns.server.config.login)
    # assigns = Map.put(assigns, :version_changeset, Mppm.ServerConfig.changeset(assigns.server.config))
    DashboardView.render("server-line.html", assigns)
  end

  def handle_event("change-version", %{"server_config" => %{"version" => version}}, socket) do
    server_name = socket.assigns.server.config.name
    Mppm.Notifications.notify(:game_server, "Restart game server #{server_name} for version change to take effect")
    changeset = Mppm.ServerConfig.changeset(socket.assigns.server.config, %{version: version})
    {:noreply, assign(socket, version_changeset: changeset)}
  end

  def handle_event("switch-version-and-restart", %{"server_config" => %{"version" => version}}, socket) do
    server = socket.assigns.server
    server_name = server.config.name
    Mppm.Notifications.notify(:game_server, "Game server #{server_name} has been restarted")
    changeset = Mppm.ServerConfig.changeset(server.config, %{version: version})

    {:ok, server_config} = Mppm.Repo.update(changeset)
    updated_server = Map.put(server, :config, server_config)
    Mppm.ServersStatuses.update_server_config(server.config.login, updated_server.config)
    changeset = Mppm.ServerConfig.changeset(updated_server.config, %{})
    GenServer.cast({:global, {:game_server, socket.assigns.server.config.login}}, :restart)
    Mppm.GameServer.Server.restart(socket.assigns.server.config.login)

    socket =
      socket
      |> assign(version_changeset: changeset)
      |> assign(server: updated_server)

    {:noreply, socket}
  end


  def handle_event("start-server", _params, socket) do
    GenServer.cast({:global, {:game_server, socket.assigns.server.config.login}}, :start)
    {:noreply, socket}
  end


  def handle_event("stop-server", _params, socket) do
    {:global, {:game_server, socket.assigns.server.config.login}}
    |> GenServer.cast(:stop)
    {:noreply, socket}
  end


  def handle_info("status-change", socket) do
    {:noreply, socket}
  end

end
