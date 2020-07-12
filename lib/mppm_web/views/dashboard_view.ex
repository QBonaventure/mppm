defmodule MppmWeb.DashboardView do
  use MppmWeb, :view
  use Phoenix.LiveComponent


  def get_available_titlepacks(), do: Mppm.ServerConfig.get_available_titlepacks()

  def get_status_icon("started", login), do:
    tag(:input, type: "button", value: "🟢", phx_click: "stop-server", phx_target: "#server-#{login}")
  def get_status_icon("starting", login), do: "🟡"
  def get_status_icon("stopped", login), do:
    tag(:input, type: "button", value: "🔴", phx_click: "start-server", phx_target: "#server-#{login}")
  def get_status_icon("failed", login), do: "X"
  def get_status_icon(_, _login), do: "?"

  def shorten_title_pack(value), do: value |> String.split("@") |> List.first()
  def shorten_controller("maniacontrol"), do: "MC"
  def shorten_controller(_), do: "???"

end
