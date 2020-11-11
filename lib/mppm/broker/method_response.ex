defmodule Mppm.Broker.MethodResponse do


  def pubsub_topic(server_login), do: "server_status_"<>server_login

  def dispatch(server_login, %XMLRPC.MethodResponse{param: params}) do
    dispatch_response(server_login, params)
  end



  defp dispatch_response(server_login, %{"Login" => login, "NickName" => nickname, "PlayerId" => player_id}) do
    user = %{login: login, nickname: nickname, player_id: player_id}
    GenServer.cast(Mppm.ConnectedUsers, {:connected_user_info, user})
  end

  defp dispatch_response(server_login, %{"UId" => track_uid} = map_info) do
    Phoenix.PubSub.broadcast(Mppm.PubSub, "maps-status", {:update_server_map, server_login, track_uid})
    Phoenix.PubSub.broadcast(Mppm.PubSub, "maps-status", {:current_track_info, server_login, track_uid})
  end


  defp dispatch_response(server_login, [%{"PlayerId" => 0} | remainder] = list) do
    Enum.each(
      remainder,
      & Phoenix.PubSub.broadcast(Mppm.PubSub, "players-status", {:user_connection_to_server, server_login, Map.get(&1, "Login")})
    )
    Enum.each(remainder, & GenServer.cast(Mppm.ConnectedUsers, {:user_connection, server_login, Map.get(&1, "Login")}))
  end

  defp dispatch_response(server_login, %{"ScriptName" => script_name}) do
    game_mode = Mppm.Repo.get_by(Mppm.Type.GameMode, script_name: script_name)
    Phoenix.PubSub.broadcast(Mppm.PubSub, "server-status", {:current_game_mode, game_mode})
  end


  defp dispatch_response(server_login, message) do
    IO.inspect message
  end


end
