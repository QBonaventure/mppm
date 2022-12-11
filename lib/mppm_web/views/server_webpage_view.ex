defmodule MppmWeb.ServerWebpageView do
  use MppmWeb, :view
  use Phoenix.LiveComponent


  def display_cp(_waypoint_number, true), do: "F"
  def display_cp(waypoint_number, _end?), do: Integer.to_string(waypoint_number)

end
