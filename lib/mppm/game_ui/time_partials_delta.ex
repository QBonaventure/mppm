defmodule Mppm.GameUI.TimePartialsDelta do
  use GenServer


  @background_style %{
    ahead: "background-positive",
    behind: "background-negative",
    equal: "background-quad-black"
  }


  def root_wrap(content \\ nil), do:
    {:manialink, [id: "time-partial-diffs", version: 3], [Mppm.GameUI.Stylesheet.get_stylesheet(), content]}

  def get_display(reference_time, user_time) do
    delta = user_time - reference_time
    {
      :frame,
      [id: "diffs", size: "36 4.5", pos: "-22 48"],
      [
        {:frame, [id: "diff-with-best", pos: "0 0", size: "36 4.5", halign: "left"], [
            {:label, [halign: "center", textsize: "2", pos: "9 -0.5", text: "Top 1"], []},
            {:label, [halign: "center", textsize: "2", pos: "27 -0.5", text: Mppm.TimeRecord.get_sign(delta)<> Mppm.TimeRecord.to_string(delta)], []},
            {:quad, [size: "18 4.5", pos: "9 0", halign: "center", class: "background-quad-black"], []},
            {:quad, [size: "18 4.5", pos: "27 0", halign: "center", class: Map.get(@background_style, Mppm.TimeRecord.compare(reference_time, user_time))], []}
        ]}
      ]
    }
    |> root_wrap
  end



  def handle_info({:player_waypoint, server_login, user_login, waypoint_nb, time}, state) do
    GenServer.call(Mppm.GameUI.TimeRecords, {:get_best_time, server_login})
    |> Map.get(:checkpoints)
    |> Enum.at(waypoint_nb)
    |> case do
      nil -> nil
      ref_time ->
        get_display(ref_time, time)
        |> Mppm.GameUI.Helper.send_to_user(server_login, user_login, 2000)
      end

    {:noreply, state}
  end


  def handle_info(_, state) do
    {:noreply, state}
  end


  def start_link(_init_value), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def init(_) do
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "records-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "maps-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "time-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "race-status")
    {:ok, %{}}
  end

end
