defmodule Mppm.Broker.RequesterServer do
  use GenServer
  require Logger


  @handshake_id_bytes <<255,255,255,255>>


  def update_ruleset(server_login, values),
    do: send_to_server(server_login, {:update_ruleset, values})

  def switch_game_mode(server_login, %Mppm.Type.GameMode{} = mode),
    do: send_to_server(server_login, {:switch_game_mode, mode})


  def request_connected_users(server_login),
    do: send_to_server(server_login, {:get_players_list})

  def add_fake_player(server_login),
    do: send_to_server(server_login, {:add_fake_player})



  ##############################################################################
  ########### Available commands with parameters for the game server ###########
  ##############################################################################

  def handle_call({:reset_base_ui, modules}, _from, state) do
    mess = %{uimodules: modules} |> Jason.encode!
    {:reply, make_request("TriggerModeScriptEventArray", ["Common.UIModules.ResetProperties", [mess]], state), state}
  end

  def handle_call({:scale_base_ui, module, new_size}, _from, state) do
    mess = %{uimodules: [%{id: module, scale: new_size, scale_update: true}]} |> Jason.encode!
    {:reply, make_request("TriggerModeScriptEventArray", ["Common.UIModules.SetProperties", [mess]], state), state}
  end

  def handle_call({:reposition_base_ui, module, {x, y}}, _from, state) do
    mess = %{uimodules: [%{id: module, position: [x, y], position_update: true}]} |> Jason.encode!
    {:reply, make_request("TriggerModeScriptEventArray", ["Common.UIModules.SetProperties", [mess]], state), state}
  end

  def handle_call({:hide_base_ui, module}, _from, state) do
    mess = %{uimodules: [%{id: module, visible: false, visible_update: true}]} |> Jason.encode!
    {:reply, make_request("TriggerModeScriptEventArray", ["Common.UIModules.SetProperties", [mess]], state), state}
  end

  def handle_call({:show_base_ui, module}, _from, state) do
    mess = %{uimodules: [%{id: module, visible: true, visible_update: true}]} |> Jason.encode!
    {:reply, make_request("TriggerModeScriptEventArray", ["Common.UIModules.SetProperties", [mess]], state), state}
  end


  # Both methods deactivated because @common_ui_modules isn't yet set, certainly WIP.
  # def handle_call(:hide_base_ui, _from, state) do
  #   mess =
  #     %{uimodules: Enum.map(@common_ui_modules, & %{id: &1, visible: false, visible_update: true})}
  #     |> Jason.encode!
  #
  #   {:reply, make_request("TriggerModeScriptEventArray", ["Common.UIModules.SetProperties", [mess]], state), state}
  # end

  # def handle_call(:show_base_ui, _from, state) do
  #   elements = ["Race_Chrono"]
  #   mess =
  #     %{uimodules: Enum.map(@common_ui_modules, & %{id: &1, visible: true, visible_update: true})}
  #     |> Jason.encode!
  #
  #   {:reply, make_request("TriggerModeScriptEventArray", ["Common.UIModules.SetProperties", [mess]], state), state}
  # end

  def handle_call(:enable_callbacks, _from, state), do:
    {:reply, make_request("EnableCallbacks", [true], state), state}

  def handle_call(:disable_callbacks, _from, state), do:
    {:reply, make_request("EnableCallbacks", [false], state), state}


  def handle_call({:get_players_list}, _from, state), do:
    {:reply, make_request("GetPlayerList", [1000, 0], state), state}

  def handle_call({:add_fake_player}, _from, state),
    do: {:reply, make_request("ConnectFakePlayer", [], state), state}


  def handle_call({:send_notice, message, _avatar_id, mood}, _from, state)
  when is_binary(message) and is_integer(mood) and mood >= 0 and mood <= 2, do:
    {:reply, make_request("SendNotice", [message, "", mood], state), state}


  ############### Manialinks
  def handle_call({:display, xml, hide_on_click?, hide_timeout}, _from, state)
  when is_binary(xml) and is_boolean(hide_on_click?) and is_integer(hide_timeout), do:
    {:reply, make_request("SendDisplayManialinkPage", [xml, hide_timeout, hide_on_click?], state), state}

  def handle_call({:display_to_client_with_id, xml, client_uid, hide_on_click?, hide_timeout}, _from, state)
  when is_binary(xml) and is_boolean(hide_on_click?) and is_integer(hide_timeout), do:
    {:reply, make_request("SendDisplayManialinkPageToId", [client_uid, xml, hide_timeout, hide_on_click?], state), state}

  def handle_call({:display_to_client_with_login, xml, client_login, hide_on_click?, hide_timeout}, _from, state)
  when is_binary(xml) and is_boolean(hide_on_click?) and is_integer(hide_timeout), do:
    {:reply, make_request("SendDisplayManialinkPageToLogin", [client_login, xml, hide_timeout, hide_on_click?], state), state}

  def handle_call({:hide_display_to_client_with_id, client_uid}, _from, state), do:
    {:reply, make_request("SendHideManialinkPageToId", [client_uid], state), state}

  def handle_call({:hide_display_to_client_with_login, client_login}, _from, state), do:
    {:reply, make_request("SendHideManialinkPageToLogin", [client_login], state), state}

  def handle_call({:kick_by_id, client_uid}, _from, state), do:
    {:reply, make_request("KickId", [client_uid], state), state}

  def handle_call({:kick_by_login, client_login}, _from, state), do:
    {:reply, make_request("Kick", [client_login], state), state}


  def handle_call({:ban_by_id, client_uid, message}, _from, state)
  when is_binary(message), do:
    {:reply, make_request("BanId", [client_uid, message], state), state}

  def handle_call({:ban_by_login, client_login, message}, _from, state)
  when is_binary(message), do:
    {:reply, make_request("Ban", [client_login, message], state), state}

  def handle_call({:unban, client_login}, _from, state), do:
    {:reply, make_request("UnBan", [client_login], state), state}

  def handle_call({:ban_and_blacklist, client_login, message, save?}, _from, state)
  when is_binary(message) and is_boolean(save?), do:
    {:reply, make_request("Kick", [client_login, message, save?], state), state}


  def handle_call({:set, :mode_id, value}, _from, state), do:
    {:reply, make_request("SetTimeAttackLimit", [value], state), state}


  def handle_call({:update_ruleset, values}, _from, state) do
    script_vars = Mppm.GameRules.get_flat_script_variables
    values =
      Enum.filter(values, fn {key, _value} -> Map.has_key?(script_vars, key) end)
      |> Enum.map(fn {key, value} -> {script_vars[key], value} end)
      |> Map.new

    {:reply, make_request("SetModeScriptSettings", [values], state), state}
  end

  def handle_call({:switch_game_mode, %Mppm.Type.GameMode{} = game_mode}, _from, state), do:
    {:reply, make_request("SetScriptName", [game_mode.script_name], state), state}



  def handle_call({:write_to_chat, message}, _from, state)
  when is_binary(message), do:
    {:reply, make_request("ChatSend", [message], state), state}


  def handle_call(:get_broker_state, _, state), do: {:reply, state, state}

  def handle_call(:start_internet, _from, state) do
      make_request("StartServerInternet", [], state)
      {:reply, :ok, state}
  end


  def handle_call(command, _from, state) do
    Logger.info("No function call can be matched for "<>inspect(command))
    {:reply, :ok, state}
  end



  def handle_cast({:force_spectator_to_target, player_login, user_login}, state) do
    make_request("ForceSpectatorTarget", [player_login, user_login, 0], state)
    {:noreply, state}
  end

  def handle_cast(:reload_match_settings, state) do
    Logger.info "["<>state.login<>"] Reloading match settings"

    make_request("LoadMatchSettings", ["MatchSettings/" <> state.login <> ".txt"], state)
    {:noreply, state}
  end

  def handle_cast(:authenticate, state) do
    make_request("Authenticate", ["SuperAdmin", state.superadmin_pwd], state)
    make_request("SetApiVersion", ["2013-04-16"], state)
    make_request("EnableCallbacks", [true], state)
    make_request("TriggerModeScriptEventArray", ["XmlRpc.EnableCallbacks", ["true"]], state)

    make_request("GetCurrentMapInfo", [], state)
    make_request("GetCurrentGameInfo", [], state)
    make_request("GetPlayerList", [1000, 0], state)

    Logger.info "["<>state.login<>"] Authenticated to the game server"
    Phoenix.PubSub.broadcast(Mppm.PubSub, "server-status:"<>state.login, {:broker_started, state.login})
    {:noreply, state}
  end


  def handle_cast({:request_user_info, user_login}, state) do
    make_request("GetDetailedPlayerInfo", [user_login], state)
    {:noreply, state}
  end

  def handle_cast(:skip_map, state) do
    make_request("NextMap", [], state)
    {:noreply, state}
  end

  def handle_cast(:restart_map, state) do
    make_request("RestartMap", [], state)
    {:noreply, state}
  end

  def handle_cast(:end_round, state) do
    make_request("TriggerModeScriptEventArray", ["Trackmania.ForceEndRound", []], state)
    {:noreply, state}
  end

  def handle_cast(:end_warmup, state) do
    make_request("TriggerModeScriptEventArray", ["Trackmania.WarmUp.ForceStopRound", []], state)
    {:noreply, state}
  end

  def handle_cast(:end_all_warmup, state) do
    make_request("TriggerModeScriptEventArray", ["Trackmania.WarmUp.ForceStop", []], state)
    {:noreply, state}
  end



  def handle_info({:connection_established, socket}, state) do
    GenServer.cast(self(), :authenticate)
    {:noreply, %{state | socket: socket, status: :connected}}
  end



  ##############################################################################
  ############################# PRIVATE FUNCTIONS ##############################
  ##############################################################################


  defp send_to_server(server_login, message) do
    proc_name = {:global, {:broker_requester, server_login}}
    case GenServer.whereis(proc_name) do
      nil ->
        {:none, :not_running}
      _pid ->
        GenServer.call(proc_name, message)
    end
  end

  defp make_request(method, params, broker_state) do
    q = build_query(method, params)
    case send_query(broker_state.socket, q) do
      :ok ->
        :ok
      {:error, :closed} ->
        Logger.error "["<>broker_state.login<>"] An error occured while sending query"
        {:error, :closed}
    end
  end


  defp build_query(method, params) do
    query =
      %XMLRPC.MethodCall{method_name: method, params: params}
      |> XMLRPC.encode!
    <<byte_size(query)::little-32>> <> @handshake_id_bytes <> query
  end


  defp send_query(socket, query), do:
    :gen_tcp.send(socket, query)



  def start_link([login, _xmlrpc_port, _superadmin_pwd] = init_args), do:
    GenServer.start_link(__MODULE__, init_args, name: {:global, {:broker_requester, login}})

  def init([login, _xmlrpc_port, superadmin_pwd]) do
    Phoenix.PubSub.subscribe(Mppm.PubSub, "broker-status:"<>login)

    init_state = %{
      socket: nil,
      login: login,
      superadmin_pwd: superadmin_pwd,
      status: :disconnected,
    }
    Logger.info "["<>login<>"] Broker requester started."

    {:ok, init_state}
  end

end
