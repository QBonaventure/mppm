defmodule MppmWeb.DashboardView do
  use MppmWeb, :view
  use Phoenix.LiveComponent


  def get_available_titlepacks(), do: Mppm.ServerConfig.get_available_titlepacks()


end
