defmodule Mppm.GameUI.BasicInfo do
  use GenServer


  def root_wrap(content \\ nil), do:
    {:manialink, [id: "basic-infos", version: 3], [Mppm.GameUI.Stylesheet.get_stylesheet(), content]}

  def current_track({track_one, track_two}) do
    {:frame, [id: "maps", pos: "-160 90"], [
      {:frame, [id: "current-map"], [
        {:label, [class: "text", pos: "1.5 -1", text: track_text(track_one)], []},
        {:quad, [class: "background-quad", pos: "0.5 -0.5", size: "40 3.2"], []},
      ]},
      {:frame, [id: "next-map", pos: "0 -3.7"], [
        {:label, [class: "text", pos: "1.5 -1", text: track_text(track_two), opacity: "0.5"], []},
        {:quad, [class: "background-quad", pos: "0.5 -0.5", size: "40 3.2", opacity: "0.1"], []},
      ]}
    ]}
  end

  defp track_text(%Mppm.Track{author_nickname: author_name, name: map_name}), do: map_name<>" by "<>author_name

  defp get_server_tracks(server_login), do:
    {
      GenServer.call(Mppm.Tracklist, {:get_server_current_track, server_login}),
      GenServer.call(Mppm.Tracklist, {:get_server_next_track, server_login})
    }


  def handle_info({:loaded_map, server_login, _map_uid}, state) do
    IO.puts "mlllllllllllllllllllllllll"
    get_server_tracks(server_login)
    |> current_track()
    |> root_wrap()
    |> Mppm.GameUI.Helper.send_to_all(server_login)
    {:noreply, state}
  end

  def handle_info(_unhandled_message, state) do
    {:noreply, state}
  end


  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def init(_) do
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "maps-status")
    {:ok, %{}}
  end

end
