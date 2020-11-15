defmodule MppmWeb.Live.Component.UsersManager do
  use Phoenix.LiveComponent

  def render(assigns) do
    MppmWeb.UsersListView.render("manager.html", assigns)
  end

end
