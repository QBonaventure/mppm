defmodule MppmWeb.Live.Component.UsersList do
  use Phoenix.LiveComponent


  def render(assigns) do
    MppmWeb.UsersListView.render("main.html", assigns)
  end



end
