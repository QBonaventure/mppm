defmodule Mppm.ConnectedUsers do
  use GenServer


  def add_server_user(state, server_login, %Mppm.User{} = user) do
    server_list = Map.get(state.servers_users, server_login, [])
    Map.put(state.servers_users, server_login, [user | server_list])
  end

  def remove_server_user(state, server_login, user_login) do
    server_list =
      Map.get(state.servers_users, server_login)
      |> Enum.reject(& &1.login == user_login)
    Map.put(state.servers_users, server_login, server_list)
  end

  def add_unknown_user(state, server_login, user_login), do:
    [%{server_login: server_login, user_login: user_login} | state.unknown_users]

  def remove_unknown_user(state, user_login), do:
    Enum.reject(state.unknown_users, & &1.user_login == user_login)



  def handle_cast({:user_connection, server_login, user_login}, state) do
    case Mppm.Repo.get_by(Mppm.User, %{login: user_login}) do
      nil ->
        :ok = GenServer.cast({:global, {:mp_broker, server_login}}, {:request_user_info, user_login})
        {:noreply, %{state | unknown_users: add_unknown_user(state, server_login, user_login)}}
      user ->
        {:noreply, %{state | servers_users: add_server_user(state, server_login, user)}}
    end
  end

  def handle_cast({:user_disconnection, server_login, user_login}, state) do
    {:noreply, %{state | servers_users: remove_server_user(state, server_login, user_login)}}
  end



  def handle_cast({:connected_user_info, %{} = user}, state) do
    case Enum.find(state.unknown_users, & &1.user_login == user.login) do
      %{server_login: server_login} ->
        {:ok, user_record} =
          %Mppm.User{}
          |> Mppm.User.changeset(user)
          |> Mppm.Repo.insert

        {:noreply, %{state |
          unknown_users: remove_unknown_user(state, user.login),
          servers_users: add_server_user(state, server_login, user_record)
        }}
      _ ->
        {:noreply, state}
    end
  end


  def handle_call(:get_state, _from, state), do: {:reply, state, state}


  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def init(_), do: {:ok, %{servers_users: %{}, unknown_users: []}}

end
