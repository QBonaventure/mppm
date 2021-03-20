defmodule MppmWeb.MainNavigationLive do
  use Phoenix.LiveView

  def render(assigns) do
    MppmWeb.LayoutView.render("main-navigation.html", assigns)
  end


  def mount(_params, session, socket) do
    Phoenix.PubSub.subscribe(Mppm.PubSub, "server-status")
    servers = build_list()

    socket =
      socket
      |> assign(user_session: session)
      |> assign(servers: servers)

    {:ok, socket}
  end


  def handle_event("restart", _params, socket) do
    :init.restart
    {:noreply, socket}
  end


  def handle_info({:created, _server}, socket) do
    {:noreply, assign(socket, servers: build_list())}
  end


  def handle_info({:deleted, _server_login}, socket) do
    {:noreply, assign(socket, servers: build_list())}
  end


  def handle_info(_unhandled_info, socket) do
    {:noreply, socket}
  end


  def build_list() do
    Mppm.Repo.all(Mppm.GameServer.Server)
    |> Enum.map(& {&1.id, &1.login})
    |> Enum.sort_by(& elem(&1, 1))
  end


end
