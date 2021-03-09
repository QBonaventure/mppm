defmodule MppmWeb.SystemOverviewLive do
  use Phoenix.LiveView

  def render(assigns) do
    MppmWeb.SystemOverviewView.render("index.html", assigns)
  end


  def mount(_params, _session, socket) do
    {:ok, socket}
  end

end
