defmodule MppmWeb.Live.Component.ServerLine do
  use Phoenix.LiveComponent
  alias MppmWeb.DashboardView

  def mount(socket) do
    {:ok, socket}
  end

  def render(assigns) do
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "server-status:"<>assigns.server.config.login)

    DashboardView.render("server-line.html", assigns)
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
