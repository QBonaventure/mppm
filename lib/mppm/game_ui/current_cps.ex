defmodule Mppm.GameUI.CurrentCPs do
  use GenServer

  @behaviour Mppm.GameUI.Module

  def name, do: "CurrentCPs"


  def compare(cps, cp_number, time, user_login)
  when is_map_key(cps, cp_number) do
    case time < Kernel.get_in(cps, [cp_number, :time]) do
      true ->
        user = Mppm.ConnectedUsers.get_user(user_login)
        updated_cps = Map.put(cps, cp_number, %{player: user.nickname, time: time})
        {:updated, updated_cps}
      false ->
        {:unchanged, cps}
    end
  end

  def compare(cps, cp_number, time, user_login) do
    user = Mppm.ConnectedUsers.get_user(user_login)
    updated_cps = Map.put(cps, cp_number, %{player: user.nickname, time: time})
    {:updated, updated_cps}
  end

  ##############################################################################
  ############################ GenServer Callbacks #############################
  ##############################################################################

  def handle_info({:loaded_map, server_login, _map_uid}, state) do
    clean_cps = %{}
    update_table(state.server_login, clean_cps)
    |> Mppm.GameUI.Helper.send_to_all(server_login)

    {:noreply, %{state | checkpoints: clean_cps}}
  end

  def handle_info({:user_connected, server_login, user}, state) do
    update_table(state.server_login, state.checkpoints)
    |> Mppm.GameUI.Helper.send_to_user(server_login, user.login)
    {:noreply, state}
  end


  def handle_info({:player_waypoint, server_login, user_login, cp_number, time}, state) do
   case compare(state.checkpoints, cp_number, time, user_login) do
     {:updated, updated_cps} ->
       update_table(state.server_login, updated_cps)
       |> Mppm.GameUI.Helper.send_to_all(server_login)
       {:noreply, %{state | checkpoints: updated_cps}}
    {:unchanged, _cps} ->
      {:noreply, state}
    end
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
    {:ok, %{server_login: server_login, checkpoints: %{}}}
  end

  def terminate(_reason, state) do
    Mppm.GameUI.Helper.send_to_all(root_wrap(), state.server_login)
    :normal
  end


  ##############################################################################
  ############################# Private Functions ##############################
  ##############################################################################

  defp root_wrap(content \\ []) do
    {:manialink, [id: "current-cps", version: 3], [
      Mppm.GameUI.Stylesheet.get_stylesheet(),
      {:frame, [pos: "122 80"], [
        {:label, [text: "CP", class: "header-text", pos: "4 0"], []},
        {:label, [text: "Time", class: "header-text", pos: "15 0"], []},
        {:label, [text: "Player", class: "header-text", pos: "22 0", halign: "left"], []},
      ]},
      {:frame, [pos: "122 76.5"], content},
      {:quad, [size: "36 4.5", pos: "123 81", class: "background-quad"], []},
    ]
  }
  end


  def update_table(_server_login, cps) do
    cps_manialink =
      cps
      |> Enum.map(&checkpoint_container/1)

    root_wrap(cps_manialink)
  end

  def checkpoint_container({cp_number, %{time: time, player: player_nickname}}) do
    {:frame, [id: Integer.to_string(cp_number), size: "37 4.5", pos: "0 -"<> Float.to_string(cp_number*4.5)], [
      {:label, [text: Integer.to_string(cp_number+1)<>".", class: "text", pos: "5 -0.7", halign: "right"], []},
      {:label, [text: Mppm.TimeRecord.to_string(time), class: "text", pos: "18 -0.7", halign: "right"], []},
      {:label, [text: player_nickname, class: "text", pos: "22 -0.7", halign: "left"], []},
      {:quad, [size: "36 4.5", pos: "1 0", class: "background-quad-black"], []}
    ]}
  end

end
