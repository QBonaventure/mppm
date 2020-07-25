defmodule Mppm.ConnectedUsers do
  use GenServer


  def handle_cast({:user_connection, server_login, user_login}, state) do
    state = %{
      total_count: state.total_count + 1,
      users: [user_login | state.users]
    }
    user = GenServer.call({:global, {:mp_broker, server_login}}, {:request_user_info, user_login}
    )

    IO.inspect user
    {:no_reply, state}
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
