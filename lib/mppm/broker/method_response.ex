defmodule Mppm.Broker.MethodResponse do
  import Mppm.PubSub, only: [broadcast: 2]


  def pubsub_topic(server_login), do: "server_status:"<>server_login

  def dispatch(server_login, %XMLRPC.MethodResponse{param: params}) do
    dispatch_response(server_login, params)
  end


  # For GetPlayerInfo response
  defp dispatch_response(server_login, %{"Login" => login, "NickName" => nickname, "SpectatorStatus" => is_spectator?}) do
    # user = %Mppm.User{login: login, nickname: nickname}
    # GenServer.cast(Mppm.ConnectedUsers, {:connected_user_info, user, is_spectator?})
    Mppm.PubSub.broadcast("player-status", {:user_info, server_login, login, nickname, is_spectator?})
  end

  defp dispatch_response(server_login, %{"UId" => uuid}) do
    broadcast("maps-status", {:current_track, server_login, uuid})
  end


  # For GetDetailedPlayerInfo response
  defp dispatch_response(server_login, %{"Login" => login, "NickName" => _nickname, "IsSpectator" => is_spectator?}) do
    user = Mppm.User.get(%Mppm.User{login: login})
    Mppm.PubSub.broadcast("player-status", {:user_connection, server_login, user, is_spectator?})
  end

  # For GetPlayerList(int, int, int)
  # PlayerId = 0 means it's the dedicated server account, so we get rid of it
  defp dispatch_response(server_login, [%{"PlayerId" => 0} | remainder]) do
    Enum.each(
      remainder,
      fn %{"Login" => login, "NickName" => _nickname, "SpectatorStatus" => spec_status} ->
        user = Mppm.User.get(%Mppm.User{login: login})
        Mppm.PubSub.broadcast("player-status", {:user_connection, server_login, user, spec_status != 0})
      end
    )
  end

  defp dispatch_response(server_login, %{"ScriptName" => script_name}) do
    game_mode = Mppm.Repo.get_by(Mppm.Type.GameMode, script_name: script_name)
    broadcast("server-status:"<>server_login, {:current_game_mode, game_mode})
  end


  defp dispatch_response(_server_login, true) do
  end


  defp dispatch_response(_server_login, message) do
    %{unhandled_message: message}
  end

end
