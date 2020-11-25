defmodule Mppm.GameUI.Controller do
  use GenServer


  def handle_info({:broker_started, _server_login}, state) do
    {:noreply, state}
  end

  def handle_info({:user_connection_to_server, server_login, user_login, _is_spectator?}, state) do
    xml = Mppm.GameUI.Helper.get_custom_template(server_login, user_login)
    Mppm.GameUI.Helper.send_to_user(xml, server_login, user_login)
    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}


  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def init(_) do
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "players-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "server-status")
    {:ok, %{}}
  end

end
