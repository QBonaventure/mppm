defmodule MppmWeb.Live.Component.CreateServerForm do
  use Phoenix.LiveComponent
  alias MppmWeb.DashboardView


  def render(assigns) do
    DashboardView.render("index.html", assigns)
  end


end
