defmodule Mppm.GameUI.CurrentCPs do
  use GenServer

  @behaviour Mppm.GameUI.Module

  # Sets how much of the previous CPs and total of it to show
  @before 2
  @max 10

  # Sets widget columns position for players' names, times and CPs position.
  @player_pos "22 0"
  @time_pos "21 0"
  @cp_n_pos "6 0"

  def name, do: "CurrentCPs"

  ##############################################################################
  ############################ GenServer Callbacks #############################
  ##############################################################################

  def handle_info({:loaded_map, server_login, _map_uid}, state) do
    clean_cps = %{}
    update_table(clean_cps)
    |> Mppm.GameUI.Helper.send_to_all(server_login)

    {:noreply, %{state | checkpoints: clean_cps}}
  end

  def handle_info({:user_connected, server_login, user}, state) do
    update_table(state.checkpoints)
    |> Mppm.GameUI.Helper.send_to_user(server_login, user.login)

    players_position =
      state.players_position
      |> Map.put(user.id, 0)
    {:noreply, %{state | players_position: players_position}}
  end


  def handle_info({:player_waypoint, server_login, user_login, cp_number, time}, state) do
    {status, cps} = update_cps(state.checkpoints, cp_number, time, user_login)
    update_table(cps, cp_number)
    |> Mppm.GameUI.Helper.send_to_user(server_login, user_login)

    case status do
      :updated -> {:noreply, %{state | checkpoints: cps}}
      :unchanged -> {:noreply, state}
    end
  end
  def handle_info({:player_end_lap, server_login, user_login, cp_number, time}, state) do
    {status, cps} = update_cps(state.checkpoints, cp_number, time, user_login)
    update_table(cps, cp_number)
    |> Mppm.GameUI.Helper.send_to_user(server_login, user_login)

    case status do
      :updated -> {:noreply, %{state | checkpoints: cps}}
      :unchanged -> {:noreply, state}
    end
  end

  def handle_info({:player_giveup, server_login, user_login}, state) do
    update_table(state.checkpoints)
    |> Mppm.GameUI.Helper.send_to_user(server_login, user_login)
    {:noreply, state}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  ##############################################################################
  ############################## GenServer Impl. ###############################
  ##############################################################################

  def child_spec([server_login]) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[server_login]]},
      restart: :transient,
    }
  end

  def start_link([server_login], _opts \\ []),
    do: GenServer.start_link(__MODULE__, [server_login], name: {:global, {__MODULE__, server_login}})

  def init([server_login]) do
    Process.flag(:trap_exit, true)
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "race-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "maps-status")
    :ok = Phoenix.PubSub.subscribe(Mppm.PubSub, "players-status")
    {:ok, %{server_login: server_login, checkpoints: %{}, players_position: %{}}}
  end

  def terminate(_reason, state) do
    root_wrap()
    |> Mppm.GameUI.Helper.send_to_all(state.server_login)
    :normal
  end


  ##############################################################################
  ############################# Private Functions ##############################
  ##############################################################################

  defp update_cps(cps, cp_number, time, user_login)
  when is_map_key(cps, cp_number+1) do
    case time < Kernel.get_in(cps, [cp_number+1, :time]) do
      true ->
        user = Mppm.ConnectedUsers.get_user(user_login)
        updated_cps = Map.put(cps, cp_number+1, %{player: user.nickname, time: time})
        {:updated, updated_cps}
      false ->
        {:unchanged, cps}
    end
  end
  defp update_cps(cps, cp_number, time, user_login) do
    user = Mppm.ConnectedUsers.get_user(user_login)
    updated_cps = Map.put(cps, cp_number+1, %{player: user.nickname, time: time})
    {:updated, updated_cps}
  end


  defp update_table(cps), do: update_table(cps, 0)
  defp update_table(cps, cp_number) do
    position = cp_number+1
    cps_to_show =
      case (cp_number - @before) < 0 do
        true -> Enum.take(cps, @max)
        false ->
          cps
          |> Enum.drop(cp_number-@before)
          |> Enum.take(@max)
      end

    Enum.map(cps_to_show, fn {cp_pos, cp} ->
      case cp_pos == position do
        true -> {cp_pos, Map.put(cp, :status, :current)}
        false -> {cp_pos, Map.put(cp, :status, :none)}
      end
    end)
    |> root_wrap()
  end

  defp root_wrap(content \\ [], position \\ 0) do
    {content, index} =
      Enum.map_reduce(content, 1, fn
        {position, cp}, acc ->
          {checkpoint_row(acc, position, cp), acc+1}
      end)
    {:manialink, [id: "current-cps", version: 3], [
      Mppm.GameUI.Stylesheet.get_stylesheet(),
      {:frame, [pos: "122 80"], [
        {:label, [text: "CP", class: "header-text", pos: @cp_n_pos, halign: "right"], []},
        {:label, [text: "Time", class: "header-text", pos: @time_pos, halign: "right"], []},
        {:label, [text: "Player", class: "header-text", pos: @player_pos, halign: "left"], []},
        {:quad, [size: "36 4.5", pos: "1 1", class: "background-quad"], []},
      ]},
      {:frame, [pos: "122 75.5"], content}
    ]
  }
  end

  defp checkpoint_row(index, position, cp) do
    frame_attrs = %{
      id: "cp-data-"<>Integer.to_string(index),
      "z-index": 10,
      pos: "0 -"<> Float.to_string((index-1)*4.5)
    }
    |> Map.to_list()

    content = [
      {:quad, Map.to_list(%{size: "36 4.5", pos: "1 1", bgcolor: cp_bgcolor(cp.status), "z-index": 2}), []},
      {:label, Map.to_list(%{text: Integer.to_string(position), class: "text", pos: @cp_n_pos, halign: "right", "z-index": 10}), []},
      {:label, Map.to_list(%{text: Mppm.TimeRecord.to_string(cp.time), class: "text", pos: @time_pos, halign: "right", "z-index": 10}), []},
      {:label, Map.to_list(%{text: cp.player, class: "text", pos: @player_pos, halign: "left", "z-index": 10}), []}
    ]
    {:frame, frame_attrs, content}
  end

  defp cp_bgcolor(:none), do: "222"
  defp cp_bgcolor(:current), do: "888"

end
