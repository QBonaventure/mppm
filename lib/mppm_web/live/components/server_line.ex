defmodule MppmWeb.Live.Component.ServerLine do
  use Phoenix.LiveComponent
  alias MppmWeb.DashboardView
  alias Mppm.GameServer.{Server,DedicatedServer}
  alias Mppm.ServerConfig
  import Ecto.Changeset

  def preload(assigns) do
    configs = Mppm.Repo.all(Mppm.ServerConfig)
    assigns
    |> Enum.map(fn assign ->
      config = Enum.find(configs, & &1.id == assign.id)
      assign
      |> Map.put(:server, config)
      |> Map.put(:status, Mppm.ServersStatuses.get_server_status(config.login))
    end)
  end

  def mount(socket) do
    Phoenix.PubSub.subscribe(Mppm.PubSub, "server-status")
    {:ok, assign(socket, servers_versions: DedicatedServer.ready_to_use_servers())}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(server: assigns.server)
      |> assign(status: assigns.status)
      |> assign(version_changeset: ServerConfig.changeset(assigns.server))
    {:ok, socket}
  end

  def render(assigns) do
    DashboardView.render("server-line.html", assigns)
  end


  ######################################################
  ##################### EVENTS #########################
  ######################################################

  def handle_event("change-version", %{"server_config" => %{"version" => version}}, socket) do
    server_name = socket.assigns.server.name
    Mppm.Notifications.notify(:game_server, "Restart game server #{server_name} for version change to take effect")
    changeset = ServerConfig.changeset(socket.assigns.server, %{version: version})
    {:noreply, assign(socket, version_changeset: changeset)}
  end

  def handle_event("switch-version-and-restart", %{"server_config" => %{"version" => version}}, socket) do
    server = socket.assigns.server
    server_config = Mppm.ServerConfig.get_server_config(server.login)
    server_name = server.login
    {:ok, dedi_server} = DedicatedServer.get(String.to_integer(version))

    {:ok, updated_config} = ServerConfig.change_version(server.login, dedi_server)
    updated_server = Map.put(server, :config, updated_config)
    changeset = ServerConfig.changeset(server_config, %{})

    Task.start(Server, :restart, [server.login])

    socket =
      socket
      |> assign(version_changeset: changeset)
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

  # def handle_info("server-status", {:started, server_login})
  # when server_login in [:starting, :started, :start_failed, :stopping, :stopped] do
  #
  # end
  #
  # def handle_info("status-change", socket) do
  #   {:noreply, socket}
  # end

  defp from_server_assign(%{config: %Mppm.ServerConfig{id: id, login: login} = config, status: status}), do:
    %{id: id, login: login, status: status, config: config}

  defp version_changeset(version, data \\ %{}) do
    data
    |> cast(data, [:version])
  end

end
