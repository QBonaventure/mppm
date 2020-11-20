defmodule Mppm.ConnectedUsers do
  use GenServer

  def get_connected_users(server_login) do
    GenServer.call(Mppm.ConnectedUsers, :get_state) |> Map.get(:servers_users) |> Map.get(server_login, [])
  end

  def get_connected_users() do
    GenServer.call(Mppm.ConnectedUsers, :get_state)
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
    IO.inspect servers_users
    Phoenix.PubSub.broadcast(Mppm.PubSub, "players-status", {:servers_users_updated, server_login, servers_users})
    servers_users
  end



  def update_user_status(state, server_login, user_login, is_spectator?) do
    server_users = Kernel.get_in(state, [:servers_users, server_login])

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



  def handle_cast({:user_connection, server_login, user_login, is_spectator?}, state) do
    case Mppm.Repo.get_by(Mppm.User, %{login: user_login}) do
      nil ->
        :ok = GenServer.cast({:global, {:broker_requester, server_login}}, {:request_user_info, user_login})
        {:noreply, %{state | unknown_users: add_unknown_user(state, server_login, user_login)}}
      user ->
        {:noreply, %{state | servers_users: add_server_user(state, server_login, user, is_spectator?)}}
    end
  end

  def handle_cast({:user_disconnection, server_login, user_login}, state) do
    {:noreply, %{state | servers_users: remove_server_user(state, server_login, user_login)}}
  end



  def handle_cast({:connected_user_info, %{"SpectatorStatus" => is_spectator?} = user}, state) do
    case Enum.find(state.unknown_users, & &1.user_login == user.login) do
      %{server_login: server_login} ->
        {:ok, user_record} =
          %Mppm.User{}
          |> Mppm.User.changeset(user)
          |> Mppm.Repo.insert

        {:noreply, %{state |
          unknown_users: remove_unknown_user(state, user.login),
          servers_users: add_server_user(state, server_login, user_record, is_spectator?)
        }}
      _ ->
        {:noreply, state}
    end
  end

  def handle_cast({:user_is_player, server_login, user_login}, state) do
    {:noreply, update_user_status(state, server_login, user_login, false)}
  end

  def handle_cast({:user_is_spectator, server_login, user_login}, state) do
    {:noreply, update_user_status(state, server_login, user_login, true)}
  end


  def handle_call(:get_state, _from, state), do: {:reply, state, state}


  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def init(_), do: {:ok, %{servers_users: %{}, unknown_users: []}}

end
