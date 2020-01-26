defmodule MppmWeb.Live.Component.ServerLine do
  use Phoenix.LiveComponent
  alias Mppm.ServerConfig
  alias MppmWeb.DashboardView
  alias Mppm.ManiaplanetServerSupervisor


  def mount(socket) do
    {:ok, socket}
  end

  def render(assigns) do
    DashboardView.render("server-line.html", assigns)
  end


  def handle_event("start-server", params, socket) do
    ManiaplanetServerSupervisor.start_mp_server(socket.assigns.server)
    {:noreply, socket}
  end



end
