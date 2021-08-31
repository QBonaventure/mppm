defmodule Mppm.GameUI.Controller do
  use GenServer


  def handle_info({:user_connected, server_login, user, _is_spectator?}, state) do
    xml = Mppm.GameUI.Helper.get_custom_template(server_login, user)
    Mppm.GameUI.Helper.send_to_user(xml, server_login, user.login)
    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  def child_spec([server_login]) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[server_login]]},
      restart: :transient
    }
  end
  def start_link([server_login], _opts \\ []),
    do: GenServer.start_link(__MODULE__, [server_login], name: {:global, {__MODULE__, server_login}})
  def init([server_login]) do
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "players-status")
    {:ok, %{}}
  end

end
