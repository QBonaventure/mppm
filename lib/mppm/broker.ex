defmodule Mppm.Broker do
  use GenServer
  alias Mppm.{ServerConfig,Statuses}
  alias Mppm.GameServerSupervisor.BinaryMessage

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


  defp open_connection(port) do
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

  def handle_call({:BanAndBlackList, client_login, message, save?}, _from, state)
  when is_binary(message) and is_boolean(save?), do:
    {:reply, make_request("Kick", [client_login, message, save?], state), state}




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
    :get_manialink_answer => "GetManialinkPageAnswers"
  }

  def handle_call(:stop, _from, state) do
    res = make_request(@methods[:quit_game], [], state)
    {:stop, :shutdown, :ok, state}
  end

  def handle_call({:query, method}, _, state)  do
    {:reply, make_request(@methods[method], [], state), state}
  end

  def handle_call({:query, method, params}, _, state) do
    {:reply, make_request(@methods[method], params, state), state}
  end

  def handle_call(:get_broker_state, _, state) do
    {:reply, state, state}
  end



  def handle_info({:tcp_closed, port}, state) do
    IO.puts "------------CLOSING BROKER CONNECTION"
    {:noreply, %{state | status: :disconnected}}
  end

  def handle_info({:tcp, _port, @handshake_response}, state) do
    {:noreply, %{state | status: :connected}}
  end


  def handle_info({:tcp, _port, binary}, %{incoming_message: nil} = state) do
    {:ok, incoming_message} = parse_new_packet(state.login, binary)
    {:noreply, %{state | incoming_message: incoming_message}}
  end


  def handle_info({:tcp, _port, binary}, %{incoming_message: incoming_message} = state) do
    {:ok, incoming_message} = parse_message_next_packet(state.login, binary, incoming_message)
    {:noreply, %{state | incoming_message: incoming_message}}
  end


  # defp parse_new_packet(_login, "GBXRemote 2"), do: {:ok, nil}
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
    GenServer.cast({:global, {:mp_server, login}}, {:incoming_game_message, message})
  end


  def get_request_id(state) do
    new_id = state.request_id + 1
    {new_id, <<new_id::little-32>>}
  end



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
    make_request("EnableCallbacks", [true], state)
    {:noreply, state}
  end


end
