defmodule MppmWeb.MainNavigationLive do
  use Phoenix.LiveView

  def render(assigns) do
    MppmWeb.LayoutView.render("main-navigation.html", assigns)
  end


  def mount(_params, session, socket) do
    servers =
      Mppm.ServersStatuses.all()
      |> Enum.map(fn {name, %{config: %{id: id}}} -> {id, name} end)
      |> Enum.sort_by(& elem(&1, 1))

    socket =
      socket
      |> assign(user_session: session)
      |> assign(servers: servers)

    {:ok, socket}
  end

end
