defmodule Mppm.GameUI.TrackKarma do
  use GenServer

  def handle_info({:user_connected, server_login, user}, state) do
    get_widget()
    |> Mppm.GameUI.Helper.send_to_user(server_login, user.login)
  end


  def handle_info({:new_track_vote, server_login, vote}) do

  end


  def handle_info({:user_connected, server_login, user}, state) do
    get_widget()
    |> Mppm.GameUI.Helper.send_to_user(server_login, user.login)
  end

  # Catch all calls that we do not care about
  def handle_info(_, state), do: {:noreply, state}

  def skj do
    # Mppm.PubSub.broadcast("track-karma", {:new_track_vote, server_login, vote})
  end

  def get_widget() do
    content =
      [
        {:label, [text: "Map Karma", class: "header-text"], []},
        {:quad, [size: "36 4.5", pos: ""]}
      ]

    {:frame, [pos: "-120 50"], content}
    |> root_wrap()
  end

  def root_wrap(content \\ nil), do:
    {:manialink, [id: "track_karma", version: 3], [Mppm.GameUI.Stylesheet.get_stylesheet(), content]}


  ##############################################################################
  ################### GenServer functions and callbacks ########################
  ##############################################################################

  def child_spec([server_login]) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[server_login]]},
      restart: :transient
    }
  end

  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def init(_) do
    state = %{}
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "track-karma")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "player-status")
    {:ok, state}
  end

  def terminate(reason, state) do
    IO.puts("I'm restarting!")
  end

end
