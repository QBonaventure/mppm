defmodule Mppm.GameUI.TrackKarma do
  use GenServer

  @rgb_hex_ratio 15.9375
  @hex_numeric_value %{
    15 => "F",
    14 => "E",
    13 => "D",
    12 => "C",
    11 => "B",
    10 => "A"
  }


  def widget(mean_vote) do
    content =
      [
        {:label, [text: "Map Karma", class: "header-text"], []},
        {:quad, [class: "background-quad", size: "36 4.5", pos: "1 1"], []},
        {:quad, [size: "36 4", pos: "1 -3.5", bgcolor: "222"], []},
        {:quad, [size: get_vote_bar_length(mean_vote)<>" 4", pos: "1 -3.5", bgcolor: get_vote_bar_hex_value(mean_vote)], []},

        {:quad, [size: "6.5 5", pos: "1 -7.5", action: "vote:1", class: "background-quad-black"], []},
        {:label, [text: "1", class: "button text", pos: "3 -9"], []},
        {:quad, [size: "6.5 5", pos: "8 -7.5",action: "vote:2", class: "background-quad-black"], []},
        {:label, [text: "2", class: "button text", pos: "10 -9"], []},
        {:quad, [size: "6.5 5", pos: "15 -7.5",action: "vote:3", class: "background-quad-black"], []},
        {:label, [text: "3", class: "button text", pos: "17 -9"], []},
        {:quad, [size: "6.5 5", pos: "22 -7.5",action: "vote:4", class: "background-quad-black"], []},
        {:label, [text: "4", class: "button text", pos: "24 -9"], []},
        {:quad, [size: "6.5 5", pos: "29 -7.5",action: "vote:5", class: "background-quad-black"], []},
        {:label, [text: "5", class: "button text", pos: "31 -9"], []}
      ]
    {:frame, [pos: "122.5 30"], content}
    |> root_wrap()
  end

  def root_wrap(content \\ nil), do:
    {:manialink, [id: "track-karma", version: 3], [Mppm.GameUI.Stylesheet.get_stylesheet(), content]}


  ##############################################################################
  ########################## GenServer Callbacks ###############################
  ##############################################################################

  def handle_info({:user_connected, server_login, user}, state) do
    widget(2)
    |> Mppm.GameUI.Helper.send_to_user(server_login, user.login)
    {:noreply, state}
  end

  def handle_info({:new_track_vote, server_login, vote}, state) do
    new_vote =
      vote
      |> Map.put(:track, %Ecto.Association.NotLoaded{__field__: :track})
      |> Map.put(:user, %Ecto.Association.NotLoaded{__field__: :user})

    user_id = new_vote.user_id

    updated_votes = Enum.map(state.votes, fn
        %{user_id: ^user_id} -> new_vote
        x -> x
      end)

    updated_mean_vote = mean_value(updated_votes)

    Mppm.GameUI.Helper.send_to_all(widget(updated_mean_vote), server_login)
    {:noreply, %{votes: updated_votes, mean_value: updated_mean_vote}}
  end

  # Catch all calls that we do not care about
  def handle_info(_, state), do: {:noreply, state}


  ##############################################################################
  ########################### Private functions ################################
  ##############################################################################

  defp get_vote_bar_length(nil), do: "0"
  defp get_vote_bar_length(mean_vote),
    do: to_string(Float.round((mean_vote-0.9)*8.8, 1))

  def get_vote_bar_hex_value(nil), do: "000"
  def get_vote_bar_hex_value(mean_vote) do
    {r, g, b} =
      case mean_vote < 2.5 do
        true -> {"F", get_hex_value(mean_vote), "0"}
        false -> {get_hex_value(5-mean_vote), "F", "0"}
      end
      r<>g<>b
  end

  defp get_hex_value(value) do
    Map.get(@hex_numeric_value, Kernel.round((value/2.5)*15), to_string(Kernel.trunc(value*6)))
  end

  defp mean_value([]), do: nil
  defp mean_value(votes) do
    votes
    |> Enum.reduce(0, fn vote, acc -> acc + vote.note end)
    |> Kernel./(Enum.count(votes))
    |> Float.round(1)
  end

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

  def start_link(init_value) do
     GenServer.start_link(__MODULE__, init_value, name: __MODULE__)
  end

  def init([server_login]) do
    {:ok, cur_track} = Mppm.Tracklist.get_server_current_track(server_login)

    votes =
      cur_track
      |> Mppm.Repo.preload(:karma_votes)
      |> Map.get(:karma_votes)

    mean_vote = mean_value(votes)
    state = %{votes: votes, mean_vote: mean_vote}

    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "maps-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "players-status")
    Mppm.GameUI.Helper.send_to_all(widget(mean_vote), server_login)

    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

end
