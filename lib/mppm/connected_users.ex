defmodule Mppm.ConnectedUsers do
  use GenServer


  def handle_cast({:user_connection, server_login, user_login}, state) do
    user =
      case Mppm.Repo.get_by(Mppm.User, %{login: user_login}) do
        nil ->
          user_data = GenServer.call({:global, {:mp_broker, server_login}}, {:request_user_info, user_login})
          %Mppm.User{}
          |> Ecto.Changeset.change(user_data)
          |> Mppm.Repo.insert
        user ->
          user
      end

    IO.inspect user
    state = %{
      total_count: state.total_count + 1,
      users: [user_login | state.users]
    }


    {:noreply, state}
  end

  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def init(_) do
    state = %{
      total_count: 0,
      users: [],
    }
    {:ok, state}
  end

end
