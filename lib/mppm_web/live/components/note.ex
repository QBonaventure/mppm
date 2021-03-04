defmodule MppmWeb.Live.Component.Note do
  use Phoenix.LiveComponent


  def mount(socket) do
    # {:ok, servers_versions} = Mppm.Service.UbiNadeoApi.server_versions()
    # socket =
    #   socket
    #   |> assign(servers_versions: servers_versions)
    #   |> assign(changeset: Mppm.ServerConfig.create_server_changeset())
    {:ok, socket}
  end

  def render(assigns) do
    MppmWeb.NotificationsView.render("note.html", assigns)
  end

end
