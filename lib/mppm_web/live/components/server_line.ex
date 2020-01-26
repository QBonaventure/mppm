defmodule MppmWeb.Live.Component.ServerLine do
  use Phoenix.LiveComponent
  alias Mppm.ServerConfig
  alias MppmWeb.DashboardView
  alias Mppm.ManiaplanetServerSupervisor


  @server "mppm_ps"
  @topic "server_status"


  def mount(socket) do
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, @topic)
    {:ok, socket}
  end

  def render(assigns) do
    DashboardView.render("server-line.html", assigns)
  end


  def handle_event("start-server", params, socket) do
    ManiaplanetServerSupervisor.start_mp_server(socket.assigns.server)
    {:noreply, socket}
  end


  def handle_info("status-change", socket) do
    IO.inspect "HALLO"
    {:noreply, socket}
  end

end
