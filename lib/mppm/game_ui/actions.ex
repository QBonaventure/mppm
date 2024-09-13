defmodule Mppm.GameUI.Actions do

  def handle_action("skip-map", server_login, _user_login, []), do:
    GenServer.cast({:global, {:broker_requester, server_login}}, :skip_map)

  def handle_action("restart-map", server_login, _user_login, []), do:
    GenServer.cast({:global, {:broker_requester, server_login}}, :restart_map)

  def handle_action("vote", server_login, user_login, [note]) do
    {:ok, track} = Mppm.Tracklist.get_server_current_track("ftc_tm20_1")
    user = Mppm.User.get(%Mppm.User{login: user_login})

    {:ok, vote} = Mppm.TrackKarma.upsert_vote(user, track, note)
    Mppm.PubSub.broadcast("maps-status", {:new_track_vote, server_login, vote})
  end

  def handle_action(method, server_login, user_login, [])
  when binary_part(method, 0, 8) == "spectate" do
    ["spectate", player_login] = String.split(method)
    GenServer.cast({:global, {:broker_requester, server_login}}, {:force_spectator_to_target, user_login, player_login})
  end

  def handle_action(method, server_login, user_login, params), do:
    %{method: method, params: params, user_login: user_login, server_login: server_login}

end
