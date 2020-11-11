defmodule Mppm.Broker.ReceiverServer do
  require Logger
  use GenServer
  alias Mppm.Broker.BinaryMessage
  alias Mppm.ServerConfig


  @handshake_response <<11,0,0,0>> <> "GBXRemote 2"
  @header_size 8
  @xmlrpc_conn_opts [:binary, {:active, true}, {:reuseaddr, true}, {:keepalive, false}, {:send_timeout, 20000}]


  def open_connection(port) do
    :gen_tcp.connect({127, 0, 0, 1}, port, @xmlrpc_conn_opts)
  end


  def pubsub_topic(server_login), do: "server_status_"<>server_login

  def handle_info({:connect, xmlrpc_port}, state) do
    {:ok, socket} = open_connection(xmlrpc_port)
    Logger.info "TCP connection established for server "<>state.login
    Phoenix.PubSub.broadcast(Mppm.PubSub, "broker-status", {:connection_established, socket})
    {:noreply, %{state | socket: socket}}
  end

  def handle_info({:tcp_closed, port}, state) do
    Logger.info "Closing broker connection for "<>state.login
    {:noreply, %{state | status: :disconnected}}
  end

  def handle_info({:tcp, _port, @handshake_response}, state), do: {:noreply, %{state | status: :connected}}
  def handle_info({:tcp, _port, "GBXRemote 2"}, state), do: {:noreply, %{state | status: :connected}}


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

  defp parse_new_packet(login, binary) do
    Logger.info "Dropped packet: "<>binary
    {:error, nil}
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

        msg_to_transmit =
          case incoming_message do
            <<150,0,0,0,255,255,255,255>> -> end_of_message
            _ -> incoming_message.message <> end_of_message
          end
        transmit_to_server_supervisor(login, msg_to_transmit)
        parse_new_packet(login, next_message)
    end
  end


  defp transmit_to_server_supervisor(login, message) do
    try do
      XMLRPC.decode! message
    rescue
      XMLRPC.DecodeError ->
        Logger.error message
        GenServer.stop :error
    else
      message -> case message do
        %XMLRPC.MethodCall{} -> Mppm.Broker.MethodCall.dispatch(login, message)
        %XMLRPC.MethodResponse{} -> Mppm.Broker.MethodResponse.dispatch(login, message)
        d ->
          # IO.inspect d
      end
    end
  end


  defp get_response_payload(socket, size) do
    {:ok, res} = :gen_tcp.recv(socket, size, 10000)
    {:ok, XMLRPC.decode! res}
  end

  defp get_response_header(socket) do
    {:ok, <<a::little-32, b::little-32>>} = :gen_tcp.recv(socket, @header_size, 10000)
    {:ok, %{size: a, id: b}}
  end



  def handle_call(:get_socket, _, state) do
    {:reply, {:ok, state.socket}, state}
  end




  def start_link([login, _, _] = init_args) do
    GenServer.start_link(__MODULE__, init_args, name: {:global, {:broker_receiver, login}})
  end

  def init([login, xmlrpc_port, superadmin_pwd]) do
    # Process.flag(:trap_exit, true)

    init_state = %{
      socket: nil,
      login: login,
      superadmin_pwd: superadmin_pwd,
      status: :disconnected,
      incoming_message: nil,
    }
    Logger.info "Broker receiver for "<>login<>" started."
    Process.send_after(self, {:connect, xmlrpc_port}, 100)
    {:ok, init_state}
  end


end
