defmodule Mppm.Broker.RequesterServer do
  use GenServer
  require Logger


  @handshake_id_bytes <<255,255,255,255>>


  def make_request(method, params, broker_state) do
    q = build_query(method, params)
    case send_query(broker_state.socket, q) do
      :ok ->
        :ok
      {:error, :closed} ->
        Logger.error "["<>broker_state.login<>"] An error occured while sending query"
        {:error, :closed}
    end
  end


  def build_query(method, params) do
    query =
      %XMLRPC.MethodCall{method_name: method, params: params}
      |> XMLRPC.encode!
    <<byte_size(query)::little-32>> <> @handshake_id_bytes <> query
  end

  def send_query(socket, query), do:
    :gen_tcp.send(socket, query)



  ##############################################################
  ### Available commands with parameters for the game server ###
  ##############################################################
  def handle_call(:enable_callbacks, _from, state), do:
    {:reply, make_request("EnableCallbacks", [true], state), state}

  def handle_call(:disable_callbacks, _from, state), do:
    {:reply, make_request("EnableCallbacks", [false], state), state}

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


  ### Ruleset updates
  def handle_call({:set, :mode_id, value}, _from, state), do:
    {:reply, make_request("SetTimeAttackLimit", [value], state), state}
      ### Ruleset updates

  @script_settings Mppm.GameRules.get_script_settings_variables


  def handle_call({:update_ruleset, values}, _from, state) do
    script_vars = Mppm.GameRules.get_flat_script_variables
    values =
      Enum.filter(values, fn {key, value} -> Map.has_key?(script_vars, key) end)
      |> Enum.map(fn {key, value} -> {script_vars[key], value} end)
      |> Map.new

    {:reply, make_request("SetModeScriptSettings", [values], state), state}
  end

  def handle_call({:switch_game_mode, %Mppm.Type.GameMode{} = game_mode}, _from, state), do:
    {:reply, make_request("SetScriptName", [game_mode.script_name], state), state}

  def handle_cast(:reload_match_settings, state) do
    Logger.info "["<>state.login<>"] Reloading match settings"

    make_request("LoadMatchSettings", ["MatchSettings/" <> state.login <> ".txt"], state)
    {:noreply, state}
  end



  def handle_call({:write_to_chat, message}, _from, state)
  when is_binary(message), do:
    {:reply, make_request("ChatSend", [message], state), state}


  #################################################################
  ### Available commands without parameters for the game server ###
  #################################################################

  @methods %{
    :list_methods => "system.listMethods",
    :get_version => "GetVersion",
    :get_max_players => "GetMaxPlayers",
    :get_status => "GetStatus",
    :get_chat => "GetChatLines",
    :get_sys_info => "GetSystemInfo",
    :quit_game => "QuitGame",
    :hide_display => "SendHideManialinkPage",
    :get_manialink_answer => "GetManialinkPageAnswers",
    :get_game_rules => "GetModeScriptSettings",
    :get_current_game_rules => "GetCurrentGameInfo",
    :get_next_game_rules => "GetNextGameInfo",
    :get_mode_script_variable => "GetModeScriptVariables",
    :get_mode_script_text => "GetModeScriptInfo",
    :get_current_map_info => "GetCurrentMapInfo",
    :get_player_list => "GetPlayerList"

  }


  def handle_call(:get_broker_state, _, state), do: {:reply, state, state}


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

  def handle_call(:start_internet, _from, state) do
      make_request("StartServerInternet", [], state)
      {:reply, :ok, state}
  end



  def handle_info({:connection_established, socket}, state) do
    GenServer.cast(self(), :authenticate)
    {:noreply, %{state | socket: socket, status: :connected}}
  end



  def start_link([login,_,_] = init_args), do:
    GenServer.start_link(__MODULE__, init_args, name: {:global, {:broker_requester, login}})

  def init([login, xmlrpc_port, superadmin_pwd]) do
    Phoenix.PubSub.subscribe(Mppm.PubSub, "broker-status")

    init_state = %{
      socket: nil,
      login: login,
      superadmin_pwd: superadmin_pwd,
      status: :disconnected,
    }
    Logger.info "["<>login<>"] Broker requester started."

    {:ok, init_state}
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
    Phoenix.PubSub.broadcast(Mppm.PubSub, "server-status", {:broker_started, state.login})
    {:noreply, state}
  end

end
