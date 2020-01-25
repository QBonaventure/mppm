defmodule MppmWeb.Live.Component.CreateServerForm do
  use Phoenix.LiveComponent
  alias Mppm.ServerConfig
  alias MppmWeb.DashboardView


  def render(assigns) do
    DashboardView.render("create-server-form.html", assigns)
  end


end
