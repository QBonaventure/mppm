defmodule MppmWeb.Live.Component.ServerLine do
  use Phoenix.LiveComponent
  alias MppmWeb.DashboardView
  alias Mppm.GameServer.{Server,DedicatedServer}

  def preload(assigns) do
    servers = Mppm.Repo.all(Mppm.GameServer.Server) |> Mppm.Repo.preload([:config, :ruleset, :tracklist])
    assigns
    |> Enum.map(fn assign ->
      server = Enum.find(servers, & &1.id == assign.id)
      status =
        case Map.get(assign, :status) do
          {_server_login, status} -> status
          nil -> Map.get(Mppm.GameServer.Server.server_status(server.login), :status)
        end
      assign
      |> Map.put(:server, server)
      |> Map.put(:status, status)
    end)
  end

  def mount(socket) do
    {:ok, assign(socket, servers_versions: DedicatedServer.ready_to_use_servers())}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(server: assigns.server)
      |> assign(status: assigns.status)
      |> assign(version_changeset: Server.changeset(assigns.server))
    {:ok, socket}
  end

  def render(assigns) do
    DashboardView.render("server-line.html", assigns)
  end


  ##############################################################################
  ################################### EVENTS ###################################
  ##############################################################################

  def handle_event("change-version", %{"server" => data}, socket) do
    changeset = Server.changeset(socket.assigns.server, data)
    {:noreply, assign(socket, version_changeset: changeset)}
  end

  def handle_event("switch-version-and-restart", %{"server" => %{"exe_version" => version}}, socket) do
    server = socket.assigns.server
    {:ok, dedicated_server} = DedicatedServer.get(String.to_integer(version))

    {:ok, updated_server} = Server.change_version(server, dedicated_server)

    Task.start(Server, :restart, [server.login])

    socket =
      socket
      |> assign(version_changeset: Server.changeset(updated_server))
      |> assign(server: updated_server)
    {:noreply, socket}
  end


  def handle_event("start-server", _params, socket) do
    Task.start(Mppm.GameServer.Server, :start, [socket.assigns.server.login])

    {:noreply, socket}
  end


  def handle_event("stop-server", _params, socket) do
    Task.start(Mppm.GameServer.Server, :stop, [socket.assigns.server.login])
    {:noreply, socket}
  end


  ##############################################################################
  ############################# PRIVATE FUNCTIONS ##############################
  ##############################################################################

  # defp server_status(server_login) do
  #   # %{status: status} = Mppm.GameServer.Server.server_status(server_login)
  #   status
  # end


end
