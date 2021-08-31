defmodule Mppm.GameUI.TimePartialsDelta do
  use GenServer
  require Logger

  @behaviour Mppm.GameUI.Module

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


  def handle_cast({:set_new_top_record, server_login, %Mppm.TimeRecord{} = new_time}, state) do
    {:noreply, Map.put(state, server_login, new_time)}
  end


  def handle_info({:loaded_map, server_login, uuid}, state) do
    case Mppm.TimeTracker.get_top_record(uuid) do
      {:ok, top_record} ->
        {:noreply, Map.put(state, server_login, top_record)}
      :none ->
        {:noreply, state}
      end
  end


  def handle_info({:new_time_record, server_login, time}, state) do
    case Map.get(state, server_login) do
      nil -> {:noreply, Map.put(state, server_login, time)}
      top_record ->
        case Mppm.TimeRecord.compare(time, top_record) do
          :ahead -> {:noreply, Map.put(state, server_login, time)}
          _ -> {:noreply, state}
        end
      end
  end

  def handle_info({:player_waypoint, server_login, user_login, waypoint_nb, time}, state) do
    best_time =
      case Map.get(state, server_login) do
        %Mppm.TimeRecord{} = best_time ->
          best_time
        :no_key ->
          {:ok, track} = Mppm.Tracklist.get_server_current_track(server_login)
           case Mppm.TimeTracker.get_top_record(track.uuid) do
             nil -> nil
             best_time -> List.first(best_time)
            end
        nil -> nil
      end

    case is_nil(best_time) do
      true ->
        {:noreply, state}
      false ->
        best_time
        |> Map.get(:checkpoints)
        |> Enum.at(waypoint_nb)
        |> case do
          nil -> nil
          ref_time ->
            get_display(ref_time, time)
            |> Mppm.GameUI.Helper.send_to_user(server_login, user_login, 3000)
          end
        {:noreply, %{state | server_login => best_time}}
    end
  end


  def handle_info(_, state) do
    {:noreply, state}
  end


  ##############################################################################
  ############################## GenServer Impl. ###############################
  ##############################################################################

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
    Process.flag(:trap_exit, true)
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "maps-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "race-status")

    Mppm.GameUI.Helper.log_module_start(server_login, name())

    {:ok, %{server_login: server_login, top_record: top_record(server_login)}, {:continue, :init_continue}}
  end

  def handle_continue(:init_continue, state) do
    {:noreply, state}
  end

  def terminate(_reason, state) do
    :normal
  end


  ##############################################################################
  ############################# Private Functions ##############################
  ##############################################################################

  defp top_record(server_login) do
    {:ok, track} = Mppm.Tracklist.get_server_current_track(server_login)
    case Mppm.TimeTracker.top_record(track) do
      {:ok, :none} ->
        :none
      {:ok, %Mppm.TimeRecord{} = record} ->
        record
    end
  end

end
