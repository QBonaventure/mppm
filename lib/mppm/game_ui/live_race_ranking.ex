defmodule Mppm.GameUI.LiveRaceRanking do
  use GenServer


  @camcorder_img_url "http://endlessicons.com/wp-content/uploads/2012/11/camcorder-icon-614x460.png"

  def root_wrap(content \\ nil), do:
    {:manialink, [id: "live-race-ranking", version: 3], [Mppm.GameUI.Stylesheet.get_stylesheet(), content]}


  def get_table(%{}) do
    base_content =
      [
        {:label, [text: "Live Race Ranking", pos: "18 0", halign: "center", class: "header-text"], []},
        {:quad, [size: "36 4.5", pos: "1 1", class: "background-quad"], []}
      ]

      {:frame, [pos: "-160 80"], base_content}
      |> root_wrap()
  end

  def get_table(waypoints_list, user_login, is_spectator?) do
    base_content =
      [
        {:label, [text: "Live Race Ranking", pos: "18 0", halign: "center", class: "header-text"], []},
        {:quad, [size: "36 4.5", pos: "1 1", class: "background-quad"], []}
      ]
      |> List.insert_at(1, table_lines(waypoints_list, user_login, is_spectator?))
      |> List.flatten

      {:frame, [pos: "-160 80"], base_content}
      |> root_wrap()
  end


  def table_lines(waypoints_list, user_login, is_spectator?) do
    {
      :frame,
      [id: "live-ranking-list", pos: "0 -3.6"],
      waypoints_list
      |> Enum.sort_by(&{-&1.waypoint_nb, &1.time})
      |> Enum.map_reduce(0, fn player_waypoint, index ->
        line =
          case is_spectator? and player_waypoint.login != user_login do
            true ->
              {:frame, [id: Integer.to_string(index+1), size: "50 50", pos: "0 "<>Float.to_string(-index*3.5)], [
                {:quad, [valign: "center", halign: "center", size: "8 8", pos: "3.5 -1.7", image: @camcorder_img_url, keepratio: "Fit", action: "spectate "<>player_waypoint.login], []},
                {:label, [text: Integer.to_string(index+1)<>".", class: "text", pos: "8 -0.7", halign: "right"], []},
                {:label, [text: player_waypoint.nickname, class: "text", pos: "9 -0.7", halign: "left"], []},
                {:label, [text: player_waypoint.waypoint_nb+1, class: "text", pos: "23 -0.7", halign: "center"], []},
                {:label, [text: Mppm.TimeRecord.to_string(player_waypoint.time), class: "text", pos: "36 -0.7", halign: "right"], []},
                {:quad, [size: "36 4.5", pos: "1 1", class: "background-quad-black"], []},
              ]}
            false ->
              {:frame, [id: Integer.to_string(index+1), size: "50 50", pos: "0 "<>Float.to_string(-index*3.5)], [
                {:label, [text: Integer.to_string(index+1)<>".", class: "text", pos: "8 -0.7", halign: "right"], []},
                {:label, [text: player_waypoint.nickname, class: "text", pos: "9 -0.7", halign: "left"], []},
                {:label, [text: player_waypoint.waypoint_nb+1, class: "text", pos: "23 -0.7", halign: "center"], []},
                {:label, [text: Mppm.TimeRecord.to_string(player_waypoint.time), class: "text", pos: "36 -0.7", halign: "right"], []},
                {:quad, [size: "36 4.5", pos: "1 1", class: "background-quad-black"], []},
              ]}
          end

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
    state = Kernel.put_in(state, [server_login, user_login], %{waypoint_nb: waypoint_nb, time: time, nickname: user_nickname, login: user_login})
    GenServer.cast(self(), {:update_table, server_login, state})
    {:noreply, state}
  end


  def handle_info({:player_giveup, server_login, user_login}, state) do
    current_list = Map.delete(Map.get(state, server_login), user_login)
    state =  %{state | server_login => current_list}
    GenServer.cast(self(), {:update_table, server_login, state})
    {:noreply, state}
  end


  def handle_info({:servers_users_updated, server_login, _servers_users}, state) do
    GenServer.cast(self(), {:update_table, server_login, state})
    {:noreply, state}
  end

  def handle_info({:started, server_login}, state) do
    case Map.has_key?(state, server_login) do
      true -> {:noreply, state}
      false -> {:noreply, Map.put(state, server_login, %{})}
    end
  end


  def handle_info(_unhandled_message, state), do:
    {:noreply, state}


  def handle_cast({:update_table, server_login, waypoints}, state) do
    if !Enum.empty?(waypoints) do
      Enum.each(Mppm.ConnectedUsers.get_connected_users(server_login), fn %{login: user_login, is_spectator?: is_spectator?} ->
        Map.get(waypoints, server_login)
        |> Enum.map(& %{waypoint_nb: Map.get(elem(&1, 1), :waypoint_nb), time: Map.get(elem(&1, 1), :time), nickname: Map.get(elem(&1, 1), :nickname), login: Map.get(elem(&1, 1), :login)})
        |> Mppm.GameUI.LiveRaceRanking.get_table(user_login, is_spectator?)
        |> Mppm.GameUI.Helper.send_to_user(server_login, user_login)
      end)
    end
    {:noreply, state}
  end


  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def init(_) do
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "race-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "players-status")
    {:ok, %{}}
  end

end
