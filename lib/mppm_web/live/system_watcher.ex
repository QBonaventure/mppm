defmodule MppmWeb.SystemWatcherLive do
  use Phoenix.LiveView

  def render(assigns) do
    MppmWeb.LayoutView.render("system-watcher.html", assigns)
  end

  def mount(_params, _session, socket) do
    :ok = Mppm.PubSub.subscribe("system-stats")
    {:ok, assign(socket, data: [])}
  end

  def handle_info({:servers_stats, data}, socket) do
    {:noreply, assign(socket, data: data)}
  end

end
