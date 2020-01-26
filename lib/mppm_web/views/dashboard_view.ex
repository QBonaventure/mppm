defmodule MppmWeb.DashboardView do
  use MppmWeb, :view
  use Phoenix.LiveComponent


  def get_available_titlepacks(), do: Mppm.ServerConfig.get_available_titlepacks()

  def get_status_icone("running"), do: "🟢";
  def get_status_icone(_), do: "🔴";

  def shorten_title_pack(value), do: value |> String.split("@") |> List.first()

end
