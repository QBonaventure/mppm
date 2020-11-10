defmodule Mppm.GameUI.LiveRaceRanking do
  use GenServer


  def root_wrap(content \\ nil), do:
    {:manialink, [id: "live-race-ranking", version: 3], [Mppm.GameUI.Stylesheet.get_stylesheet(), content]}


  def get_table(waypoints_list) do
    quad_size = "36 "<> Integer.to_string(4*Enum.count(waypoints_list)+6)
    base_content =
      [
        {:label, [text: "Live Race Ranking", pos: "18 0", halign: "center", class: "header-text"], []},
        {:quad, [size: quad_size, pos: "1 1", class: "background-quad"], []}
      ]
      |> List.insert_at(1, table_lines(waypoints_list))
      |> List.flatten

      {:frame, [pos: "-160 -30"], base_content}
      |> root_wrap()
  end


  def table_lines(waypoints_list) do
    {
      :frame,
      [id: "live-ranking-list", pos: "0 -5"],
      waypoints_list
      |> Enum.sort_by(&{-&1.waypoint_nb, &1.time})
      |> Enum.map_reduce(0, fn player_waypoint, index ->
        line =
          {:frame, [id: Integer.to_string(index+1), size: "50 50", pos: "2 "<>Integer.to_string(-index*4)], [
              {:label, [text: Integer.to_string(index+1)<>".", class: "text", pos: "3 0", halign: "right"], []},
              {:label, [text: player_waypoint.nickname, class: "text", pos: "4 0", halign: "left"], []},
              {:label, [text: player_waypoint.waypoint_nb+1, class: "text", pos: "20 0", halign: "center"], []},
              {:label, [text: Mppm.TimeRecord.to_string(player_waypoint.time), class: "text", pos: "33 0", halign: "right"], []}
        ]}
        {line, index+1}
      end)
      |> elem(0)
    }
  end


  def handle_info({:turn_start, server_login}, state) do
    state = Map.put(state, server_login, %{})
    Mppm.GameUI.LiveRaceRanking.get_table(%{})
    |> Mppm.GameUI.Helper.send_to_all(server_login)

    {:noreply, state}
  end

  def handle_info({:player_waypoint, server_login, user_login, waypoint_nb, time}, state) do
    user_nickname =
      Mppm.ConnectedUsers.get_connected_users(server_login)
      |> Enum.find(& &1.login == user_login)
      |> Map.get(:nickname)

    state =
      Map.put(state, server_login, %{})
      |> Kernel.put_in([server_login, user_login], %{waypoint_nb: waypoint_nb, time: time, nickname: user_nickname})

    GenServer.cast(self(), {:update_table, server_login, state})

    {:noreply, state}
  end

  def handle_cast({:update_table, server_login, waypoints}, state) do
    xml =
      Map.get(waypoints, server_login)
      |> Enum.map(& %{waypoint_nb: Map.get(elem(&1, 1), :waypoint_nb), time: Map.get(elem(&1, 1), :time), nickname: Map.get(elem(&1, 1), :nickname)})
      |> Mppm.GameUI.LiveRaceRanking.get_table()
      |> Mppm.GameUI.Helper.send_to_all(server_login)
    {:noreply, state}
  end


  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def init(a) do
    IO.inspect a
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "race-status")
    {:ok, %{}}
  end

end
