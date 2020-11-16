defmodule Mppm.GameUI.Actions do

  def handle_action("skip-map", server_login, user_login, []), do:
    GenServer.cast({:global, {:broker_requester, server_login}}, :skip_map)

  def handle_action("restart-map", server_login, user_login, []), do:
    GenServer.cast({:global, {:broker_requester, server_login}}, :restart_map)

  def handle_action(method, _server_login, _user_login, params), do:
    IO.inspect %{method: method, params: params}

end
