defmodule Mppm.Broker.MethodCall do



  def pubsub_topic(server_login), do: "server_status_"<>server_login



  def dispatch(server_login, %XMLRPC.MethodCall{method_name: "ManiaPlanet.ModeScriptCallbackArray", params: [callback_name, [raw_data]]}) do
    {:ok, data} = Jason.decode(raw_data)
    IO.inspect callback_name
    dispatch_script_callback(server_login, callback_name, data)
  end


  def dispatch_script_callback(server_login, "Trackmania.Event.WayPoint", data) do
    Phoenix.PubSub.broadcast(Mppm.PubSub, Mppm.TimeTracker.get_pubsub_topic(), {data, server_login})
  end

  def dispatch_script_callback(_server_login, "ManiaPlanet.ModeScriptCallbackArray", _data) do
  end

  def dispatch_script_callback(_server_login,  "Trackmania.Event.StartLine", _data) do
  end

  def dispatch_script_callback(_server_login, "Trackmania.Event.GiveUp", _data) do
  end

  def dispatch_script_callback(_server_login, "Trackmania.Event.SkipOutro", _data) do
  end

  def dispatch_script_callback(_server_login, "Trackmania.Event.Respawn", _data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.StartServer_Start", _data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.StartServer_End", _data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.StartMatch_Start", _data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.StartMatch_End", _data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.LoadingMap_Start", _data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.LoadingMap_End", _data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.StartMap_Start", _data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.StartMap_End", _data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.StartRound_Start", _data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.StartRound_End", _data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.StartTurn_Start", _data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.StartTurn_End", _data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.StartPlayLoop", _data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.EndPlayLoop", _data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.EndTurn_Start", _data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.EndTurn_End", _data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.EndRound_Start", _data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.EndRound_End", _data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.EndMap_Start", _data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.EndMap_End", _data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.Podium_Start", _data) do
  end

  def dispatch_script_callback(_server_login, "Maniaplanet.Podium_End", _data) do
  end

  def dispatch_script_callback(_server_login, "Trackmania.Scores", _data) do
  end


  def dispatch_script_callback(_server_login, unknown_callback, data) do
    IO.inspect %{script_callback: unknown_callback, data: data}
  end





  def dispatch(server_login, %XMLRPC.MethodCall{method_name: "ManiaPlanet.EndMatch"}) do
    Phoenix.PubSub.broadcast(Mppm.PubSub, pubsub_topic(server_login), {:endmatch})
  end


  def dispatch(server_login, %XMLRPC.MethodCall{method_name: "ManiaPlanet.EndMap", params: data}) do
    Phoenix.PubSub.broadcast(Mppm.PubSub, "maps-status", {:endmap, server_login, List.first(data) |> Map.get("UId")})
    Phoenix.PubSub.broadcast(Mppm.PubSub, pubsub_topic(server_login), {:endmap})
  end


  def dispatch(server_login, %XMLRPC.MethodCall{method_name: "ManiaPlanet.BeginMap", params: data}) do
    Phoenix.PubSub.broadcast(Mppm.PubSub, "maps-status", {:beginmap, server_login, List.first(data) |> Map.get("UId")})
    Phoenix.PubSub.broadcast(Mppm.PubSub, pubsub_topic(server_login), {:beginmap, List.first(data)})
  end


  def dispatch(server_login, %XMLRPC.MethodCall{method_name: "ManiaPlanet.BeginMatch", params: data}) do
    Phoenix.PubSub.broadcast(Mppm.PubSub, pubsub_topic(server_login), {:beginmatch})
  end


  def dispatch(server_login, %XMLRPC.MethodCall{method_name: "ManiaPlanet.PlayerChat", params: data}) do
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


  def dispatch(server_login, %XMLRPC.MethodCall{method_name: "ManiaPlanet.PlayerConnect", params: data}) do
    Phoenix.PubSub.broadcast(Mppm.PubSub, "players-status", {:user_connection_to_server, server_login, List.first(data)})
    GenServer.cast(Mppm.ConnectedUsers, {:user_connection, server_login, List.first(data)})
  end


  def dispatch(server_login, %XMLRPC.MethodCall{method_name: "ManiaPlanet.PlayerDisconnect", params: data}) do
    GenServer.cast(Mppm.ConnectedUsers, {:user_disconnection, server_login, List.first(data)})
  end


  def dispatch(server_login, %XMLRPC.MethodCall{method_name: "ManiaPlanet.PlayerInfoChanged", params: [data]}) do
  end


  def dispatch(server_login, %XMLRPC.MethodCall{} = message) do
    IO.inspect message
  end


end
