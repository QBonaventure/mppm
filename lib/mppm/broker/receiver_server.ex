defmodule Mppm.Broker.ReceiverServer do
  use GenServer
  alias Mppm.Broker.BinaryMessage
  alias Mppm.ServerConfig


  @handshake_response <<11,0,0,0>> <> "GBXRemote 2"
  @header_size 8


  def pubsub_topic(server_login), do: "server_status_"<>server_login

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
            Phoenix.PubSub.broadcast(Mppm.PubSub, "players-status", {:user_connection_to_server, login, List.first(message.params)})
            GenServer.cast(Mppm.ConnectedUsers, {:user_connection, login, List.first(message.params)})
          "ManiaPlanet.PlayerDisconnect" ->
            GenServer.cast(Mppm.ConnectedUsers, {:user_disconnection, login, List.first(message.params)})
          "ManiaPlanet.ModeScriptCallbackArray" ->
            case message.params do
              ["Trackmania.Event.WayPoint", data] ->
                Phoenix.PubSub.broadcast(Mppm.PubSub, Mppm.TimeTracker.get_pubsub_topic(), {Jason.decode!(data), login})
              _ ->
            end
          _ ->
        end
      %XMLRPC.MethodResponse{param: %{"Login" => login, "NickName" => nickname, "PlayerId" => player_id}} ->
        user = %{login: login, nickname: nickname, player_id: player_id}
        GenServer.cast(Mppm.ConnectedUsers, {:connected_user_info, user})
      %XMLRPC.MethodResponse{param: %{"UId" => track_uid} = map_info} ->
        Phoenix.PubSub.broadcast(Mppm.PubSub, "maps-status", {:update_server_map, login, track_uid})
        Phoenix.PubSub.broadcast(Mppm.PubSub, pubsub_topic(login), {:current_map_info, map_info})
      %XMLRPC.MethodResponse{param: [%{"PlayerId" => 0} | remainder] = list} ->
        Enum.each(
          remainder,
          & Phoenix.PubSub.broadcast(Mppm.PubSub, "players-status", {:user_connection_to_server, login, Map.get(&1, "Login")})
        )
        Enum.each(remainder, & GenServer.cast(Mppm.ConnectedUsers, {:user_connection, login, Map.get(&1, "Login")}))
      d ->
    end

    GenServer.cast({:global, {:mp_server, login}}, {:incoming_game_message, message})
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
    Process.flag(:trap_exit, true)
    {:ok, socket} = Mppm.Broker.Supervisor.open_connection(xmlrpc_port)

    init_state = %{
      socket: socket,
      login: login,
      superadmin_pwd: superadmin_pwd,
      status: :disconnected,
      incoming_message: nil,
    }
    {:ok, init_state}
  end

end
