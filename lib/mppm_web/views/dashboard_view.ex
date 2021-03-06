defmodule MppmWeb.DashboardView do
  use MppmWeb, :view
  use Phoenix.LiveComponent


  def get_available_titlepacks(), do: Mppm.ServerConfig.get_available_titlepacks()

  def get_status_icon(:started, login), do:
    tag(:img, src: "/images/web_ui/power-button-on.svg", phx_click: "stop-server", phx_target: "#server-#{login}")
  def get_status_icon(:starting, _login), do:
    tag(:img, src: "/images/web_ui/power-button-starting.svg")
  def get_status_icon(:stopped, login), do:
    tag(:img, src: "/images/web_ui/power-button-off.svg", phx_click: "start-server", phx_target: "#server-#{login}")
  def get_status_icon(:failed, _login), do:
    tag(:img, src: "/images/web_ui/power-button-failed.svg")
  def get_status_icon(_, _login), do:
    "?"

end
