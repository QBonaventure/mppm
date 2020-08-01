defmodule MppmWeb.ServerManagerLive do
  use Phoenix.LiveView
  alias Mppm.Repo

  def render(assigns) do
    MppmWeb.ServerManagerView.render("index.html", assigns)
  end

  def mount(params, _session, socket) do

    server_config = Mppm.ServerConfig.get_server_config(params["server_login"])
    changeset = Ecto.Changeset.change(server_config)


    mxo =
      %Mppm.MXQuery{}
      |> Mppm.MXQuery.changeset

    # tracklist = Mppm.Tracklist.get(server_config.login)

    IO.inspect Mppm.Tracklist.get_server_tracklist(server_config.login)

    socket =
      socket
      |> assign(changeset: changeset)
      |> assign(server_info: server_config)
      |> assign(mx_query_options: mxo)
      |> assign(track_style_options: Mppm.Repo.all(Mppm.TrackStyle))
      |> assign(tracklist: Mppm.Tracklist.get_server_tracklist(server_config.login))
      |> assign(mx_tracks_result: get_data())
      |> assign(game_modes: Mppm.Repo.all(Mppm.Type.GameMode))

    {:ok, socket}
  end

  def broker_pname(server_login), do: {:global, {:mp_broker, server_login}}


  def handle_event("update-config", params, socket) do
    {:ok, changeset} = get_changeset(socket.assigns.server_info.id, params["server_config"])
    Mppm.ServerConfig.update(changeset)

    {:noreply, socket}
  end


  def handle_event("skip-map", params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server_info.login), :skip_map)
    {:noreply, socket}
  end

  def handle_event("restart-map", params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server_info.login), :restart_map)
    {:noreply, socket}
  end

  def handle_event("end-round", params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server_info.login), :end_round)
    {:noreply, socket}
  end

  def handle_event("end-warmup", params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server_info.login), :end_warmup)
    {:noreply, socket}
  end

  def handle_event("end-all-warmup", params, socket) do
    GenServer.cast(broker_pname(socket.assigns.server_info.login), :end_all_warmup)
    {:noreply, socket}
  end





  def handle_event("validate-mx-query", params, socket) do
  IO.inspect Mppm.MXQuery.changeset(socket.assigns.mx_query_options.data, params["mx_query"])
    {:noreply, assign(
      socket,
      mx_query_options: Mppm.MXQuery.changeset(socket.assigns.mx_query_options.data, params["mx_query"]
    ))}
  end

  def handle_event("send-mx-request", params, socket) do
    res =
      socket.assigns.mx_query_options.data
      |> Mppm.MXQuery.changeset(params["mx_query"])
      |> Ecto.Changeset.apply_changes
      |> Mppm.MXQuery.make_request

    {:noreply, assign(socket, mx_tracks_result: res)}
  end

  def handle_event("add-mx-track", params, socket) do
    {mx_track_id, ""} = params["data"] |> String.split("-") |> List.last |> Integer.parse
    track = get_mx_track_map(mx_track_id, socket.assigns.mx_tracks_result.tracks)


    # spawn_link(fn -> Mppm.TracksFiles.get_mx_track_file(track) end)

    tracklist = Mppm.Tracklist.add_track(socket.assigns.tracklist, track, params["index"]-1)

    # tracklist = List.insert_at(socket.assigns.tracklist, params["index"]-1, track)

    IO.inspect tracklist

    {:noreply, assign(socket, tracklist: tracklist)}
  end



  def handle_event("validate", params, socket) do
    {:ok, changeset} = get_changeset(socket.assigns.server_info.id, params["server_config"])

    {:noreply, assign(socket, changeset: changeset)}
  end

  def get_mx_track_map(mx_track_id, tracks_list) when is_integer(mx_track_id) do
    Enum.find(tracks_list, & &1.mx_track_id == mx_track_id)
  end

  def get_changeset(server_id, params) do
    changeset =
      Mppm.ServerConfig
      |> Mppm.Repo.get_by(%{id: server_id})
      |> Mppm.Repo.preload(ruleset: [:mode])
      |> Mppm.ServerConfig.changeset(params)

    case Ecto.Changeset.apply_action(changeset, :update) do
      {:error, changeset} ->
        {:ok, changeset}
      {:ok, _ } ->
        {:ok, changeset}
    end
  end


def get_data(), do:
%{
  pagination: %{item_count: 8, items_per_page: 20, page: 1},
  tracks: [
    %Mppm.Track{

      author_id: 22532,
      author_login: "c7Xrsxl9Q3So27To_V7G1A",
      author_nickname: "dedejo",
      awards_nb: 2,
      exe_ver: "3.3.0",
      gbx_map_name: "$i$s$F00E$F20u$F40p$F60h$F90o$FB0r$FD0i$FF0a",
      id: nil,
      laps_nb: 1,
      name: "Euphoria",
      mx_track_id: 3784,
      track_uid: "GO0bl9Yi7Xm2bsTBYouE5ISKWD9",
      updated_at: "2020-07-24T21:15:35.127",
      uploaded_at: "2020-07-24T21:15:35.127"
    },
    %Mppm.Track{

      author_id: 22532,
      author_login: "c7Xrsxl9Q3So27To_V7G1A",
      author_nickname: "dedejo",
      awards_nb: 0,
      exe_ver: "3.3.0",
      gbx_map_name: "$i$s$600M$fecinitech $600#$fec4",
      id: nil,
      laps_nb: 1,
      name: "Minitech #4",
      mx_track_id: 3263,
      track_uid: "B4rtiRlJ1cH5p2WchCkC1UttPF0",
      updated_at: "2020-07-20T15:26:11.77",
      uploaded_at: "2020-07-20T15:26:11.77"
    },
    %Mppm.Track{

      author_id: 22532,
      author_login: "c7Xrsxl9Q3So27To_V7G1A",
      author_nickname: "dedejo",
      awards_nb: 0,
      exe_ver: "3.3.0",
      gbx_map_name: "$i$s$FFFW$EEFa$CCFv$BBFy$99F $88FB$66Fl$55Fu$33Fe",
      id: nil,
      laps_nb: 1,
      name: "Wavy Blue",
      mx_track_id: 2327,
      track_uid: "uSZebpJ0UM0_iXepvG0Jub92kH8",
      updated_at: "2020-07-13T13:23:04.237",
      uploaded_at: "2020-07-13T13:23:04.237"
    },
    %Mppm.Track{

      author_id: 22532,
      author_login: "c7Xrsxl9Q3So27To_V7G1A",
      author_nickname: "dedejo",
      awards_nb: 6,
      exe_ver: "3.3.0",
      gbx_map_name: "$i$s$003F$004l$005y$006 $006A$448w$88Aa$CCCy",
      id: nil,
      laps_nb: 1,
      name: "Fly Away",
      mx_track_id: 1441,
      track_uid: "wl3AT_LgcVICZXewaK6KXyKidBb",
      updated_at: "2020-07-08T12:56:01.91",
      uploaded_at: "2020-07-08T12:56:01.91"
    },
    %Mppm.Track{

      author_id: 22532,
      author_login: "c7Xrsxl9Q3So27To_V7G1A",
      author_nickname: "dedejo",
      awards_nb: 3,
      exe_ver: "3.3.0",
      gbx_map_name: "$i$s$600M$fecinitech $600#$fec3",
      id: nil,
      laps_nb: 1,
      name: "Minitech #3",
      mx_track_id: 1333,
      track_uid: "ZNV_LpLJbc1YPGLWpY9EJEU6133",
      updated_at: "2020-07-07T17:05:39.627",
      uploaded_at: "2020-07-07T17:05:39.627"
    },
    %Mppm.Track{

      author_id: 22532,
      author_login: "c7Xrsxl9Q3So27To_V7G1A",
      author_nickname: "dedejo",
      awards_nb: 0,
      exe_ver: "3.3.0",
      gbx_map_name: "$i$s$600M$fecinitech $600#$fec2",
      id: nil,
      laps_nb: 1,
      name: "Minitech #2",
      mx_track_id: 1196,
      track_uid: "LsOHCHFYCiJonnWrPGo33mNonC3",
      updated_at: "2020-07-06T19:29:18.447",
      uploaded_at: "2020-07-06T19:29:18.447"
    },
    %Mppm.Track{

      author_id: 22532,
      author_login: "c7Xrsxl9Q3So27To_V7G1A",
      author_nickname: "dedejo",
      awards_nb: 3,
      exe_ver: "3.3.0",
      gbx_map_name: "$i$s$600M$fecinitech $600#$fec1",
      id: nil,
      laps_nb: 1,
      name: "Minitech #1",
      mx_track_id: 1080,
      track_uid: "FOiMnlFgmWKO6B6A2Kojojtvjs6",
      updated_at: "2020-07-06T07:41:47.19",
      uploaded_at: "2020-07-06T07:41:47.19"
    },
    %Mppm.Track{

      author_id: 22532,
      author_login: "c7Xrsxl9Q3So27To_V7G1A",
      author_nickname: "dedejo",
      awards_nb: 0,
      exe_ver: "3.3.0",
      gbx_map_name: "$i$s$7F0C$8F1u$8F2t$9F3e$9F5 $AF6a$BF7n$BF8d$CF9 $DFAm$DFCe$EFDs$EFEs$FFFy",
      id: nil,
      laps_nb: 1,
      name: "Cute and messy",
      mx_track_id: 305,
      track_uid: "FNjAjESKQf1lWKxCFOdzrPhdvS0",
      updated_at: "2020-07-02T20:01:53.347",
      uploaded_at: "2020-07-02T20:01:53.347"
    }
  ]
}

end
