defmodule Mppm.ConnectedUsers do
  use GenServer


  def get_user(user_login) do
    case where_is_user(user_login) do
      nil ->
        Mppm.Repo.get_by(Mppm.User, login: user_login)
      server_login ->
        get_connected_users(server_login)
        |> Enum.find(& &1.login == user_login)
    end
  end

  def get_user_nickname(user_login) do
    get_user(user_login)
    |> Map.get(:nickname)
  end

  def get_connected_users(server_login) do
    GenServer.call(Mppm.ConnectedUsers, :get_state) |> Map.get(:servers_users) |> Map.get(server_login, [])
  end

  def get_connected_users() do
    GenServer.call(Mppm.ConnectedUsers, :get_state)
  end

  def connected_users() do
    GenServer.call(Mppm.ConnectedUsers, :get_state)
    |> Map.get(:servers_users)
  end

  def where_is_user(user_login) do
    GenServer.call(Mppm.ConnectedUsers, :get_state)
    |> Map.get(:servers_users)
    |> Enum.find(fn {_, users} ->
      Enum.any?(users, & &1.login == user_login)
    end)
    |> case do
      {server_login, [_user]} -> server_login
      _ -> nil
    end
  end

  def add_server_user(state, server_login, %Mppm.User{} = user, is_spectator?) do
    server_list = Map.get(state.servers_users, server_login, [])
    servers_users = Map.put(state.servers_users, server_login, Enum.uniq([Map.put(user, :is_spectator?, is_spectator?) | server_list]))

    Phoenix.PubSub.broadcast(Mppm.PubSub, "players-status", {:servers_users_updated, server_login, servers_users})
    servers_users
  end



  def update_user_status(state, server_login, user_login, is_spectator?) do
    server_users =
      case Kernel.get_in(state, [:servers_users, server_login]) do
        nil -> []
        users -> users
      end

    case Enum.find(server_users, & &1.login == user_login) do
      nil -> state
      user ->
        server_users =
          [Map.put(user, :is_spectator?, is_spectator?)] ++ server_users
          |> Enum.uniq_by(& &1.login)

        new_state = Kernel.put_in(state, [:servers_users, server_login], server_users)
        Phoenix.PubSub.broadcast(Mppm.PubSub, "players-status", {:servers_users_updated, server_login, new_state.servers_users})
        new_state
    end
  end

  def remove_server_user(state, server_login, user_struct) do
    server_list =
      Map.get(state.servers_users, server_login, [])
      |> Enum.reject(& &1.login == user_struct)
    servers_users = Map.put(state.servers_users, server_login, server_list)
    Phoenix.PubSub.broadcast(Mppm.PubSub, "players-status", {:servers_users_updated, server_login, servers_users})
    servers_users
  end

  def add_unknown_user(state, server_login, user_login), do:
    [%{server_login: server_login, user_login: user_login} | state.unknown_users]

  def remove_unknown_user(state, user_login), do:
    Enum.reject(state.unknown_users, & &1.user_login == user_login)


  ##############################################################################
  ################################ Handle Info #################################
  ##############################################################################


  def handle_info({:user_connection, server_login, user, is_spectator?}, state) do
    Mppm.PubSub.broadcast("players-status", {:user_connected, server_login, user})
    {:noreply, %{state | servers_users: add_server_user(state, server_login, user, is_spectator?)}}
  end

  def handle_info({:user_disconnection, server_login, user_login}, state) do
    Mppm.PubSub.broadcast("players-status", {:user_disconnected, server_login, user_login})
    {:noreply, %{state | servers_users: remove_server_user(state, server_login, user_login)}}
  end

  def handle_info({:stopped, server_login}, state) do
    updated_servers_users = Map.delete(state.servers_users, server_login)
    {:noreply, %{state | servers_users: updated_servers_users}}
  end

  def handle_info(_unhandled_message, state) do
    {:noreply, state}
  end


  def handle_cast({:user_is_player, server_login, user_login}, state) do
    {:noreply, update_user_status(state, server_login, user_login, false)}
  end

  def handle_cast({:user_is_spectator, server_login, user_login}, state) do
    {:noreply, update_user_status(state, server_login, user_login, true)}
  end


  def handle_call(:get_state, _from, state), do: {:reply, state, state}


  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def init(_) do
    Mppm.PubSub.subscribe("player-status")
    Mppm.PubSub.subscribe("server-status")
    {:ok, %{servers_users: %{}, unknown_users: []}}
  end

end
