defmodule MppmWeb.Live.Component.ServerLine do
  use Phoenix.LiveComponent
  alias MppmWeb.DashboardView
  alias Mppm.ManiaplanetServerSupervisor

  @topic "server_status"


  def mount(socket) do
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, @topic)
    {:ok, socket}
  end

  def render(assigns) do
    DashboardView.render("server-line.html", assigns)
  end


  def handle_event("start-server", _params, socket) do
    server = Mppm.Repo.get(Mppm.ServerConfig, socket.assigns.server.id)
    spawn(ManiaplanetServerSupervisor, :start_mp_server, [server])
    Phoenix.PubSub.broadcast(Mppm.PubSub, "server_status", :update)

    {:noreply, assign(socket, server: server)}
  end


  def handle_event("stop-server", _params, socket) do
    ManiaplanetServerSupervisor.stop_mp_server(socket.assigns.id)
    {:noreply, socket}
  end


  def handle_info("status-change", socket) do
    {:noreply, socket}
  end

end
