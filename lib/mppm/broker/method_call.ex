defmodule Mppm.Broker.MethodCall do


  def dispatch(server_login, %XMLRPC.MethodCall{method_name: "ManiaPlanet.ModeScriptCallbackArray", params: [callback_name, [raw_data]]}) do
    {:ok, data} = Jason.decode(raw_data)
    dispatch_script_callback(server_login, callback_name, data)
  end

  def dispatch(server_login, %XMLRPC.MethodCall{method_name: method_name, params: data}) do
    dispatch_message(server_login, method_name, data)
  end

  def dispatch_script_callback(server_login, "Trackmania.Event.WayPoint",
  %{"login" => user_login, "checkpointinrace" => waypoint_nb, "laptime" => time,
    "isendlap" => lap?, "isendrace" => race?}) do
    case {lap?, race?} do
      {false, false} ->
        broadcast("race-status", {:player_waypoint, server_login, user_login, waypoint_nb, time})
      {true, false} ->
        broadcast("race-status", {:player_end_lap, server_login, user_login, waypoint_nb, time})
      {_, true} ->
        broadcast("race-status", {:player_end_race, server_login, user_login, waypoint_nb, time})
    end
  end

  def dispatch_script_callback(server_login,  "Trackmania.Event.StartLine",
  %{"accountid" => _user_uid, "login" => user_login, "time" => _time}) do
    broadcast("race-status", {:player_start, server_login, user_login})
  end

  def dispatch_script_callback(server_login, "Trackmania.Event.GiveUp",
  %{"accountid" => _user_uid, "login" => user_login, "time" => _time}) do
    broadcast("race-status", {:player_giveup, server_login, user_login})
  end

  def dispatch_script_callback(server_login, "Trackmania.Event.Respawn",
  %{"accountid" => _user_uid, "login" => user_login, "checkpointinlap" => _waypoint_in_lap, "checkpointinrace" => _waypoint_in_race,
  "laptime" => _laptime, "racetime" => _racetime, "speed" => _speed, "nbrespawns" => _respawns_nb, "time" => _time}) do
    broadcast("race-status", {:player_respawn, server_login, user_login})
  end

  def dispatch_script_callback(_server_login, "Trackmania.Event.SkipOutro", _data) do
  end

  def dispatch_script_callback(server_login, "Maniaplanet.StartServer_Start",
  %{"mode" => %{"name" => _mode_name, "updated" => _updated?}, "restarted" => _restarted?, "time" => _time}) do
    broadcast("server-status", {:end_of_game, server_login})
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.StartServer_End",
  %{"mode" => %{"name" => _mode_name, "updated" => _updated}, "restarted" => _restarted?, "time" => _time}) do
  end

  def dispatch_script_callback(server_login, "Maniaplanet.StartMatch_Start",
  %{"count" => _count, "time" => _time}) do
    broadcast("server-status", {:start_of_match, server_login})
  end

  def dispatch_script_callback(server_login, "Maniaplanet.StartMatch_End",
  %{"count" => _count, "time" => _time}) do
    broadcast("server-status", {:end_of_game, server_login})
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.LoadingMap_Start",
  %{"restarted" => _restarted?, "time" => _time}) do
  end

  def dispatch_script_callback(server_login, "Maniaplanet.LoadingMap_End",
  %{"map" => %{"uid" => map_uid}, "restarted" => _restarted?, "time" => _time}) do
    broadcast("maps-status", {:loaded_map, server_login, map_uid})
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.UnloadingMap_Start",
  %{"map" => _track_map}) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.UnloadingMap_End",
  %{"time" => _time}) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.StartMap_Start",
  %{"count" => _count, "time" => _time, "map" => _track_map, "restarted" => _restarted?}) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.StartMap_End",
  %{"count" => _count, "time" => _time, "map" => _track_map, "restarted" => _restarted?}) do
  end

  # data =
  def dispatch_script_callback(_server_login, "Maniaplanet.StartRound_Start",
  %{"count" => _count, "time" => _time}) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.StartRound_End",
  %{"count" => _count, "time" => _time}) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.StartTurn_Start",
  %{"count" => _count, "time" => _time}) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.StartTurn_End",
  %{"count" => _count, "time" => _time}) do
  end

  def dispatch_script_callback(server_login, "Maniaplanet.StartPlayLoop",
  %{"count" => _count, "time" => _time}) do
    broadcast("race-status", {:turn_start, server_login})
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.EndPlayLoop",
  %{"count" => _count, "time" => _time}) do
    # GenServer.cast({:global, {:broker_requester, server_login}}, :reload_match_settings)
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.EndTurn_Start",
  %{"count" => _count, "time" => _time}) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.EndTurn_End",
  %{"count" => _count, "time" => _time}) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.EndRound_Start",
  %{"count" => _count, "time" => _time}) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.EndRound_End",
  %{"count" => _count, "time" => _time}) do
  end

  def dispatch_script_callback(server_login, "Maniaplanet.EndMap_Start",
  %{"map" => _track_map, "count" => _count}) do
    broadcast("server-status", {:end_of_game, server_login})
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.EndMap_End",
  %{"map" => _track_map, "count" => _count, "time" => _time}) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.EndMatch_Start", _data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.EndMatch_End",
  %{"count" => _count, "time" => _time}) do
  end

  def dispatch_script_callback(server_login, "Maniaplanet.Podium_Start",
  %{"time" => _time}) do
    broadcast("server-status", {:podium_start, server_login})
  end

  def dispatch_script_callback(server_login, "Maniaplanet.Podium_End",
  %{"time" => _time}) do
    broadcast("server-status", {:podium_end, server_login})
  end

  def dispatch_script_callback(server_login, "Trackmania.Scores",
  %{"players" => _players_map_list, "responseid" => _response_id, "section" => _section, "teams" => _teams_list,
  "useteams" => _use_teams?, "winnerplayer" => _winner_player, "winnerteam" => _winning_team}) do
    broadcast("server-status", {:score, server_login})
  end


  def dispatch_script_callback(_server_login, unknown_callback, data) do
    IO.inspect %{script_callback: unknown_callback, data: data}
  end






  def dispatch_message(_server_login, "ManiaPlanet.StatusChanged", [_status_code, _status_name]) do
  end

  def dispatch_message(_server_login, "ManiaPlanet.MapListModified", [_cur_track_index, _next_map_index, _is_list_modified?]) do
  end

  def dispatch_message(server_login, "ManiaPlanet.EndMatch", [_list_of_user_ranking, _winning_team_id]) do
    broadcast("server-status", {:endmatch, server_login})
  end

  def dispatch_message(server_login, "ManiaPlanet.EndMap", [%{"UId" => uuid} = _track_info_map]) do
    broadcast("maps-status", {:endmap, server_login, uuid})
    broadcast("server-status", {:endmap, server_login})
  end


  def dispatch_message(server_login, "ManiaPlanet.BeginMap", [%{"UId" => uuid} = track_info_map]) do
    broadcast("maps-status", {:beginmap, server_login, uuid})
    broadcast("server-status", {:beginmap, server_login, track_info_map})
  end


  def dispatch_message(server_login, "ManiaPlanet.BeginMatch", []) do
    broadcast("server-status", {:beginmatch, server_login})
  end


  def dispatch_message(server_login, "ManiaPlanet.PlayerChat", data) do
    {user, text} =
      case data do
        [0, _, text, _] ->
          case Regex.scan(~r"\[(.*)\]\s(.*)", text, capture: :all_but_first) do
            [[player_nick, text]] -> {Mppm.Repo.get_by(Mppm.User, nickname: player_nick), text}
            _ -> {nil, nil}
          end
        [_, player_login, text, _] ->
          {Mppm.Repo.get_by(Mppm.User, login: player_login), text}
      end

    unless text == nil do
      server = Mppm.Repo.get_by(Mppm.GameServer.Server, login: server_login)
      {:ok, chat_message} =
        %Mppm.ChatMessage{}
        |> Mppm.ChatMessage.changeset(user, server, %{text: text})
        |> Mppm.Repo.insert
      broadcast("server-status", {:new_chat_message, chat_message})
    end
  end


  def dispatch_message(server_login, "ManiaPlanet.PlayerConnect", [user_login, is_spectator?]) do
    user = Mppm.User.get(%Mppm.User{login: user_login})
    broadcast("player-status", {:user_connection, server_login, user, is_spectator?})
  end


  def dispatch_message(server_login, "ManiaPlanet.PlayerDisconnect", [user_login, _reason]) do
    Mppm.PubSub.broadcast("player-status", {:user_disconnection, server_login, user_login})
  end


  def dispatch_message(server_login, "ManiaPlanet.PlayerInfoChanged", [player_info_map]) do
    case player_info_map do
      %{"SpectatorStatus" => 0, "Login" => user_login} ->
        GenServer.cast(Mppm.ConnectedUsers, {:user_is_player, server_login, user_login})
      %{"Login" => user_login} ->
        GenServer.cast(Mppm.ConnectedUsers, {:user_is_spectator, server_login, user_login})
    end
  end

  def dispatch_message(server_login, "ManiaPlanet.PlayerManialinkPageAnswer", [_, user_login, method_call, params]), do:
    Mppm.GameUI.Actions.handle_action(method_call, server_login, user_login, params)


  def dispatch_message(_server_login, method_name, data) do
    IO.inspect %{method: method_name, data: data}, label: "Unhandled message"
  end

  defp broadcast(topic, msg) do
    Phoenix.PubSub.broadcast(Mppm.PubSub, topic, msg)
  end



end
