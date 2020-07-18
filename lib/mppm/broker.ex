defmodule Mppm.Broker do
  use GenServer
  alias Mppm.{ServerConfig,Statuses}
  alias Mppm.GameServerSupervisor.BinaryMessage

  @xmlrpc_conn_opts [:binary, {:active, true}, {:reuseaddr, true}, {:keepalive, true}, {:send_timeout, 20000}]
  @handshake_id_bytes <<255,255,255,255>>
  @handshake_response <<11,0,0,0>> <> "GBXRemote 2"
  @header_size 8

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

  def make_request(method, params, broker_state) do
    q = build_query(method, params)
    case send_query(broker_state.socket, q) do
      :ok -> :ok
      {:error, :closed} -> {:error, :closed}
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

  @methods %{
    :list_methods => "system.listMethods",
    :get_version => "GetVersion",
    :get_max_players => "GetMaxPlayers",
    :get_status => "GetStatus",
    :get_chat => "GetChatLines",
    :get_sys_info => "GetSystemInfo",
    :quit_game => "QuitGame"
  }

  @methods_with_params %{
    :enable_callbacks => "EnableCallbacks"
  }

  def handle_call(:stop, _from, state) do
    res = make_request(@methods[:quit_game], [], state)
    {:reply, res, state}
  end

  def handle_call(:enable_callbacks, _, state), do:
    {:reply, make_request("EnableCallbacks", [true], state), state}

  def handle_call(:disable_callbacks, _, state), do:
    {:reply, make_request("EnableCallbacks", [false], state), state}

  def handle_call({:query, method}, _, state)  do
    {:reply, make_request(@methods[method], [], state), state}
  end

  def handle_call({:query, method, params}, _, state) do
    {:reply, make_request(@methods[method], params, state), state}
  end

  def handle_call(:get_broker_state, _, state) do
    {:reply, state, state}
  end

  def handle_info({:tcp, _port, @handshake_response}, state) do
    {:noreply, %{state | status: :connected}}
  end

  def handle_info({:tcp, _port, binary}, state) do
    state = case state.incoming_message do
      nil ->
        case binary do
          <<size::little-32,id::little-32>> ->
            %{state | incoming_message: %BinaryMessage{size: size, id: id}}
          <<size::little-32>> ->
            %{state | incoming_message: %BinaryMessage{size: size}}
          <<size::little-32,id::little-32,msg::binary>> ->
            case size == byte_size(msg) do
              true ->
                transmit_to_server_supervisor(state.login, msg)
                %{state | incoming_message: nil}
              false ->
                inc_msg = %BinaryMessage{message: msg, size: size, id: id}
                %{state | incoming_message: inc_msg}
            end
        end
      %BinaryMessage{size: size, message: message} ->
        string = message <> binary
        case byte_size(string) == size do
          true ->
            transmit_to_server_supervisor(state.login, string)
            %{state | incoming_message: nil}
          false ->
            %{state | incoming_message: %{state.incoming_message | message: string}}
        end
    end

    {:noreply, state}
  end

  def handle_info({:tcp_closed, port}, state) do
    IO.puts "------------CLOSING BROKER CONNECTION"
    {:noreply, %{state | status: :disconnected}}
  end


  defp transmit_to_server_supervisor(login, message) do
    message = XMLRPC.decode! message
    GenServer.cast({:global, {:mp_server, login}}, {:incoming_game_message, message})
  end


  def get_request_id(state) do
    new_id = state.request_id + 1
    {new_id, <<new_id::little-32>>}
  end

end
