defmodule Mppm.Broker do
  use GenServer
  alias Mppm.{ServerConfig,Statuses}
  alias Mppm.Broker.BinaryMessage

  @xmlrpc_conn_opts [:binary, {:active, true}, {:reuseaddr, true}, {:keepalive, true}, {:send_timeout, 20000}]
  @handshake_id_bytes <<255,255,255,255>>
  @handshake_response <<11,0,0,0>> <> "GBXRemote 2"
  @header_size 8

  def make_request(method, params, broker_state) do
    q = build_query(method, params)
    case send_query(broker_state.socket, q) do
      :ok ->
        :ok
      {:error, :closed} ->
        IO.puts "-----BROKER: an error occured while sending query"
        {:error, :closed}
    end
  end

  def build_query(method, params) do
    query =
      %XMLRPC.MethodCall{method_name: method, params: params}
      |> XMLRPC.encode!
    <<byte_size(query)::little-32>> <> @handshake_id_bytes <> query
  end


  def open_connection(port) do
    :gen_tcp.connect({127, 0, 0, 1}, port, @xmlrpc_conn_opts)
  end

  def send_query(socket, query) do
    :gen_tcp.send(socket, query)
  end

  defp get_response_payload(socket, size) do
    {:ok, res} = :gen_tcp.recv(socket, size, 10000)
    {:ok, XMLRPC.decode! res}
  end

  defp get_response_header(socket) do
    {:ok, <<a::little-32, b::little-32>>} = :gen_tcp.recv(socket, @header_size, 10000)
    {:ok, %{size: a, id: b}}
  end


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

  def handle_call(:reload_match_settings, _from, state) do
    {:reply, make_request("LoadMatchSettings", ["MatchSettings/" <> state.login <> ".txt"], state), state}
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

  def handle_call(:stop, _from, state) do
    res = make_request(@methods[:quit_game], [], state)
    {:stop, :shutdown, :ok, state}
  end

  def handle_call({:query, method}, _, state) when :erlang.is_map_key(method, @methods), do:
    {:reply, make_request(@methods[method], [], state), state}

  def handle_call({:query, method, params}, _, state), do:
    {:reply, make_request(@methods[method], params, state), state}

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



  def handle_info({:tcp_closed, port}, state) do
    IO.puts "------------CLOSING BROKER CONNECTION"
    {:noreply, %{state | status: :disconnected}}
  end

  def handle_info({:tcp, _port, @handshake_response}, state), do: {:noreply, %{state | status: :connected}}

  def handle_info({:tcp, _port, binary}, %{incoming_message: nil} = state) do
    {:ok, incoming_message} = parse_new_packet(state.login, binary)
    {:noreply, %{state | incoming_message: incoming_message}}
  end

  def handle_info({:tcp, _port, binary}, %{incoming_message: incoming_message} = state) do
    {:ok, incoming_message} = parse_message_next_packet(state.login, binary, incoming_message)
    {:noreply, %{state | incoming_message: incoming_message}}
  end



  defp parse_new_packet(_login, <<size::little-32,id::little-32>>), do: {:ok, %BinaryMessage{size: size, id: id}}
  defp parse_new_packet(_login, <<size::little-32>>), do: {:ok, %BinaryMessage{size: size}}

  defp parse_new_packet(login, <<size::little-32,id::little-32,msg::binary>>) do
    case size - byte_size(msg) do
      _offset when _offset > 0 ->
        {:ok, %BinaryMessage{message: msg, size: size, id: id}}
      0 ->
        transmit_to_server_supervisor(login, msg)
        {:ok, nil}
      _ ->
        <<message::binary-size(size), next_message::binary>> = msg
        transmit_to_server_supervisor(login, message)
        parse_new_packet(login, next_message)
      end
  end

  defp parse_message_next_packet(login, binary, %BinaryMessage{} = incoming_message) do
    missing_bytes = incoming_message.size - byte_size(incoming_message.message)
    case missing_bytes - byte_size(binary) do
      _offset when _offset > 0 ->
        {:ok, %{incoming_message | message: incoming_message.message <> binary}}
      0 ->
        transmit_to_server_supervisor(login, incoming_message.message <> binary)
        {:ok, nil}
      _ ->
        <<end_of_message::binary-size(missing_bytes), next_message::binary>> = binary
        transmit_to_server_supervisor(login, incoming_message.message <> end_of_message)
        parse_new_packet(login, next_message)
    end
  end


  defp transmit_to_server_supervisor(login, message) do
    message = XMLRPC.decode! message

    case message do
      %XMLRPC.MethodCall{} ->
        case message.method_name do
          "ManiaPlanet.EndMatch" ->
            Phoenix.PubSub.broadcast(Mppm.PubSub, pubsub_topic(login), {:endmatch})
          "ManiaPlanet.EndMap" ->
            Phoenix.PubSub.broadcast(Mppm.PubSub, "maps-status", {:endmap, login, List.first(message.params) |> Map.get("UId")})
            Phoenix.PubSub.broadcast(Mppm.PubSub, pubsub_topic(login), {:endmap})
          "ManiaPlanet.BeginMap" ->
            Phoenix.PubSub.broadcast(Mppm.PubSub, "maps-status", {:beginmap, login, List.first(message.params) |> Map.get("UId")})
            Phoenix.PubSub.broadcast(Mppm.PubSub, pubsub_topic(login), {:beginmap, List.first(message.params)})
          "ManiaPlanet.BeginMatch" ->
            Phoenix.PubSub.broadcast(Mppm.PubSub, pubsub_topic(login), {:beginmatch})
          "ManiaPlanet.PlayerChat" ->
            {user, text} =
              case message.params do
                [0, _, text, _] ->
                  [[player_nick, text]] = Regex.scan(~r"\[(.*)\]\s(.*)", text, capture: :all_but_first)
                  {Mppm.Repo.get_by(Mppm.User, nickname: player_nick), text}
                [_, player_login, text, _] ->
                  {Mppm.Repo.get_by(Mppm.User, login: player_login), text}
              end
            server = Mppm.Repo.get_by(Mppm.ServerConfig, login: login)
            {:ok, chat_message} =
              %Mppm.ChatMessage{}
              |> Mppm.ChatMessage.changeset(user, server, %{text: text})
              |> Mppm.Repo.insert

            Phoenix.PubSub.broadcast(Mppm.PubSub, pubsub_topic(login), {:new_chat_message, chat_message})
          "ManiaPlanet.PlayerConnect" ->
            GenServer.cast(Mppm.ConnectedUsers, {:user_connection, login, List.first(message.params)})
          "ManiaPlanet.PlayerDisconnect" ->
            GenServer.cast(Mppm.ConnectedUsers, {:user_disconnection, login, List.first(message.params)})
          _ ->
        end
      %XMLRPC.MethodResponse{param: %{"Login" => login, "NickName" => nickname, "PlayerId" => player_id}} ->
        user = %{login: login, nickname: nickname, player_id: player_id}
        GenServer.cast(Mppm.ConnectedUsers, {:connected_user_info, user})
      %XMLRPC.MethodResponse{param: %{"UId" => track_uid} = map_info} ->
        Phoenix.PubSub.broadcast(Mppm.PubSub, "maps-status", {:update_server_map, login, track_uid})
        Phoenix.PubSub.broadcast(Mppm.PubSub, pubsub_topic(login), {:current_map_info, map_info})
      _ -> nil
    end

    GenServer.cast({:global, {:mp_server, login}}, {:incoming_game_message, message})
  end

def handle_call(:start_internet, _from, state) do
    make_request("StartServerInternet", [], state)
    {:reply, :ok, state}
end

  def get_request_id(state) do
    new_id = state.request_id + 1
    {new_id, <<new_id::little-32>>}
  end

  %XMLRPC.MethodCall{
    method_name: "ManiaPlanet.EndMatch",
    params: [
      [
        %{
          "Login" => "mr2_md43Qg-_ZeOmUQ32pA",
          "NickName" => "Rrrazzziel",
          "PlayerId" => 237,
          "Rank" => 1
        }
      ],
      -1
    ]
  }

  def pubsub_topic(server_login), do: "server_status_"<>server_login


  ###############################################
  ### GenServer startup / terminate functions ###
  ###############################################

  def child_spec(game_server_config, xmlrpc_port) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [
        [
          game_server_config.login,
          game_server_config.superadmin_pass,
          xmlrpc_port
        ],
        []
      ]},
      restart: :transient
    }
  end


  def start_link([login, superadmin_pwd, xmlrpc_port], _opts \\ []) do
    GenServer.start_link(__MODULE__, [login, superadmin_pwd, xmlrpc_port], name: {:global, {:mp_broker, login}})
  end

  def init([login, superadmin_pwd, xmlrpc_port]) do
    Process.flag(:trap_exit, true)

    {:ok, socket} = open_connection(xmlrpc_port)

    state = %{
      login: login,
      superadmin_pwd: superadmin_pwd,
      socket: socket,
      request_id: 2147483648,
      status: :disconnected,
      incoming_message: nil
    }

    {:ok, state, {:continue, :authenticate}}
  end

  def handle_continue(:authenticate, state) do
    make_request("Authenticate", ["SuperAdmin", state.superadmin_pwd], state)
    make_request("SetApiVersion", ["2013-04-16"], state)
    make_request("EnableCallbacks", [true], state)
    make_request("TriggerModeScriptEventArray", ["XmlRpc.EnableCallbacks", ["true"]], state)

    make_request("GetCurrentMapInfo", [], state)
    make_request("GetPlayerList", [1000, 0], state)

    {:noreply, state}
  end


end
