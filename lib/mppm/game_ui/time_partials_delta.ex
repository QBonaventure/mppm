defmodule Mppm.GameUI.TimePartialsDelta do
  use GenServer
  require Logger

  @behaviour Mppm.GameUI.Module

  @background_style %{
    ahead: "background-positive",
    behind: "background-negative",
    equal: "background-quad-black"
  }

  def name, do: "TimePartialsDelta"

  def root_wrap(content \\ nil), do:
    {:manialink, [id: "time-partial-diffs", version: 3], [Mppm.GameUI.Stylesheet.get_stylesheet(), content]}

  def get_display(reference_time, user_time) do
    delta = user_time - reference_time

    {
      :frame,
      [id: "diffs", size: "36 45", pos: "-19 39", align: "center"],
      [
        {:frame, [id: "diff-with-best", pos: "0 -4.6", size: "36 10", halign: "left"], [
            {:label, [halign: "right", textsize: "2.5", pos: "8 -1", text: "Loc1", textfont: "Oswald", textcolor: "fff"], []},
            {:label, [halign: "right", textsize: "3.1", pos: "26 -1", text: Mppm.TimeRecord.get_sign(delta)<>Mppm.TimeRecord.to_string(delta), textfont: "Oswald", textcolor: "fff"], []},
            {:quad, [size: "9 7", pos: "0 0", halign: "left", class: "background-quad-black", bgcolor: "000", opacity: "1"], []},
            {:quad, [size: "18 7", pos: "27 0", halign: "right", opacity: "1", class: Map.get(@background_style, Mppm.TimeRecord.compare(reference_time, user_time))], []}
        ]}
      ]
    }
    |> root_wrap
  end


  def handle_info({:loaded_map, server_login, uuid}, state) do
    {:noreply, %{state | top_record: top_record(server_login)}}
  end


  def handle_info({:new_time_record, server_login, time}, state) do
    case Map.get(state, :top_record) do
      nil ->
        {:noreply, %{state | top_record: time}}
      top_record ->
        case Mppm.TimeRecord.compare(time, top_record) do
          :ahead -> {:noreply, %{state | top_record: time}}
          _ -> {:noreply, state}
        end
      end
  end

  def handle_info({:player_waypoint, server_login, user_login, waypoint_nb, time}, state) do
    case state.top_record do
      :none ->
        {:noreply, state}
      %Mppm.TimeRecord{} = top_record ->
        top_record
        |> Map.get(:checkpoints)
        |> Enum.at(waypoint_nb)
        |> case do
          nil -> nil
          ref_time ->
            get_display(ref_time, time)
            |> Mppm.GameUI.Helper.send_to_user(server_login, user_login, 3000)
          end
        {:noreply, state}
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
