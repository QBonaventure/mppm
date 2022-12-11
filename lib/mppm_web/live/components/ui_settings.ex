defmodule MppmWeb.Live.Component.UISettings do
  use Phoenix.LiveComponent


  def render(assigns) do
    MppmWeb.ServerManagerView.render("ui_settings.html", assigns)
  end



end
