defmodule MppmWeb.AppSettingsLive do
  use Phoenix.LiveView

  def render(assigns) do
    MppmWeb.LayoutView.render("app_settings.html", assigns)
  end


  def mount(_params, session, socket) do
    socket =
      socket
      |> assign(user_session: session)
      |> assign(server_versions: Mppm.GameServer.DedicatedServer.list_versions())

    {:ok, socket}
  end

  def handle_params(%{}, uri, socket) do
    {:noreply, socket}
  end

end
