defmodule Mppm.Broker.MethodCall do


  def pubsub_topic(server_login), do: "server_status_"<>server_login



  def dispatch(server_login, %XMLRPC.MethodCall{method_name: "ManiaPlanet.ModeScriptCallbackArray", params: [callback_name, [raw_data]]}) do
    {:ok, data} = Jason.decode(raw_data)
    dispatch_script_callback(server_login, callback_name, data)
  end

  def dispatch(server_login, %XMLRPC.MethodCall{method_name: method_name, params: data}) do
    dispatch_message(server_login, method_name, data)
  end



  def dispatch_script_callback(server_login, "Trackmania.Event.WayPoint", %{"login" => user_login, "checkpointinrace" => waypoint_nb, "laptime" => time} = data) do
    Phoenix.PubSub.broadcast(Mppm.PubSub, "race-status", {:player_waypoint, server_login, user_login, waypoint_nb, time})
    GenServer.cast(Mppm.TimeTracker, {:player_waypoint, server_login, data})
  end

  def dispatch_script_callback(_server_login,  "Trackmania.Event.StartLine",
  %{"accountid" => _user_uid, "login" => _user_login, "time" => _time}) do
  end

  def dispatch_script_callback(_server_login, "Trackmania.Event.GiveUp",
  %{"accountid" => _user_uid, "login" => _user_login, "time" => _time}) do
  end

  def dispatch_script_callback(_server_login, "Trackmania.Event.Respawn",
  %{"accountid" => _user_uid, "login" => _user_login, "checkpointinlap" => _waypoint_in_lap, "checkpointinrace" => _waypoint_in_race,
  "laptime" => _laptime, "racetime" => _racetime, "speed" => _speed, "nbrespawns" => _respawns_nb, "time" => _time}) do
  end

  def dispatch_script_callback(_server_login, "Trackmania.Event.SkipOutro", data) do
    IO.inspect data
  end

  def dispatch_script_callback(server_login, "Maniaplanet.StartServer_Start",
  %{"mode" => %{"name" => _mode_name, "updated" => _updated?}, "restarted" => _restarted?, "time" => _time}) do
    Phoenix.PubSub.broadcast(Mppm.PubSub, "server-status", {:end_of_game, server_login})
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.StartServer_End", data) do
    IO.inspect data
  end

  def dispatch_script_callback(server_login, "Maniaplanet.StartMatch_Start",
  %{"count" => _count, "time" => _time}) do
    Phoenix.PubSub.broadcast(Mppm.PubSub, "server-status", {:start_of_match, server_login})
  end

  def dispatch_script_callback(server_login, "Maniaplanet.StartMatch_End",
  %{"count" => _count, "time" => _time}) do
    Phoenix.PubSub.broadcast(Mppm.PubSub, "server-status", {:end_of_game, server_login})
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.LoadingMap_Start",
  %{"restarted" => _restarted?, "time" => _time}) do
  end

  def dispatch_script_callback(server_login, "Maniaplanet.LoadingMap_End",
  %{"map" => %{"uid" => map_uid}, "restarted" => _restarted?, "time" => _time}) do
    Phoenix.PubSub.broadcast(Mppm.PubSub, "maps-status", {:loaded_map, server_login, map_uid})
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
    Phoenix.PubSub.broadcast(Mppm.PubSub, "race-status", {:turn_start, server_login})
  end

  def dispatch_script_callback(server_login, "Maniaplanet.EndPlayLoop",
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
    Phoenix.PubSub.broadcast(Mppm.PubSub, "server-status", {:end_of_game, server_login})
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.EndMap_End",
  %{"map" => _track_map, "count" => _count, "time" => _time}) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.EndMatch_Start", data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.EndMatch_End",
  %{"count" => _count, "time" => _time}) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.Podium_Start",
  %{"time" => _time}) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.Podium_End",
  %{"time" => _time}) do
  end

  def dispatch_script_callback(_server_login, "Trackmania.Scores",
  %{"players" => _players_map_list, "responseid" => _response_id, "section" => _section, "teams" => _teams_list,
  "useteams" => _use_teams?, "winnerplayer" => _winner_player, "winnerteam" => _winning_team}) do
  end


  def dispatch_script_callback(_server_login, unknown_callback, data) do
    IO.inspect %{script_callback: unknown_callback, data: data, jjj: "dsqsd"}
  end






  def dispatch_message(server_login, "ManiaPlanet.StatusChanged", [_status_code, _status_name]) do
  end

  def dispatch_message(server_login, "ManiaPlanet.MapListModified", [_cur_track_index, _next_map_index, _is_list_modified?]) do
  end

  def dispatch_message(server_login, "ManiaPlanet.EndMatch", [_list_of_user_ranking, _winning_team_id]) do
    Phoenix.PubSub.broadcast(Mppm.PubSub, pubsub_topic(server_login), {:endmatch})
  end

  def dispatch_message(server_login, "ManiaPlanet.EndMap", [%{"UId" => track_uid} = _track_info_map]) do
    Phoenix.PubSub.broadcast(Mppm.PubSub, "maps-status", {:endmap, server_login, track_uid})
    Phoenix.PubSub.broadcast(Mppm.PubSub, pubsub_topic(server_login), {:endmap})
  end


  def dispatch_message(server_login, "ManiaPlanet.BeginMap", [%{"UId" => track_uid} = track_info_map]) do
    Phoenix.PubSub.broadcast(Mppm.PubSub, "maps-status", {:beginmap, server_login, track_uid})
    Phoenix.PubSub.broadcast(Mppm.PubSub, pubsub_topic(server_login), {:beginmap, track_info_map})
  end


  def dispatch_message(server_login, "ManiaPlanet.BeginMatch", []) do
    Phoenix.PubSub.broadcast(Mppm.PubSub, pubsub_topic(server_login), {:beginmatch})
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
      server = Mppm.Repo.get_by(Mppm.ServerConfig, login: server_login)
      {:ok, chat_message} =
        %Mppm.ChatMessage{}
        |> Mppm.ChatMessage.changeset(user, server, %{text: text})
        |> Mppm.Repo.insert
      Phoenix.PubSub.broadcast(Mppm.PubSub, pubsub_topic(server_login), {:new_chat_message, chat_message})
    end
  end


  def dispatch_message(server_login, "ManiaPlanet.PlayerConnect", [user_login, _is_spectator]) do
    Phoenix.PubSub.broadcast(Mppm.PubSub, "players-status", {:user_connection_to_server, server_login, user_login})
    GenServer.cast(Mppm.ConnectedUsers, {:user_connection, server_login, user_login})
  end


  def dispatch_message(server_login, "ManiaPlanet.PlayerDisconnect", [user_login, _reason]) do
    GenServer.cast(Mppm.ConnectedUsers, {:user_disconnection, server_login, user_login})
  end


  def dispatch_message(server_login, "ManiaPlanet.PlayerInfoChanged", _player_info_map) do
  end

  def dispatch_message(server_login, "ManiaPlanet.PlayerManialinkPageAnswer", [_, user_login, method_call, params]), do:
    Mppm.GameUI.Actions.handle_action(method_call, server_login, user_login, params)


  def dispatch_message(server_login, method_name, data) do
    IO.inspect %{method: method_name, data: data}
  end


end
