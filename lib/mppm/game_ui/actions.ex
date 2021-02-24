defmodule Mppm.GameUI.Actions do

  def handle_action("skip-map", server_login, _user_login, []), do:
    GenServer.cast({:global, {:broker_requester, server_login}}, :skip_map)

  def handle_action("restart-map", server_login, _user_login, []), do:
    GenServer.cast({:global, {:broker_requester, server_login}}, :restart_map)

  def handle_action(method, server_login, user_login, [])
  when binary_part(method, 0, 8) == "spectate" do
    ["spectate", player_login] = String.split(method)
    GenServer.cast({:global, {:broker_requester, server_login}}, {:force_spectator_to_target, user_login, player_login})
  end

  def handle_action(method, server_login, user_login, params), do:
    %{method: method, params: params, user_login: user_login, server_login: server_login}

end
