# Game server message broker

A broker is made up of one supervisor (Mppm.Broker.Supervisor) and two GenServers:
- Mppm.Broker.ReceiverServer
- Mppm.Broker.RequesterServer

The Supervisor is started after game server launch, once the XMLRPC port is detected. The
ReceiverServer then opens the connection and provides a call method so that the
RequesterServer can retrieve the open port. Everything's stopped on server shutdown.

This design choice has been made to allow either the receiving or requesting part
of the broker to be able to independently fail without impeding its counterpart.

References of the XML/RPC methods and callbacks can be found
<a href="https://doc.maniaplanet.com/dedicated-server/references/xml-rpc-methods">
here.</a>



## Requester server

This is the Genserver in charge of managing everything going into the dedicated server.

It doesnt connect to the dedicated server on start, but waits for the ReveiverServer to do so first, and publish a `{:connection_established, socket}` message on the `{broker-status:**server_login**}` topic. Only then does the RequesterServer start:
```
  def handle_info({:connection_established, socket}, state) do
    GenServer.cast(self(), :authenticate)
    {:noreply, %{state | socket: socket, status: :connected}}
  end
```

### Making calls to the dedicated server

To access the dedicated server API, calls must be made through the RequesterServer API. The server login always is required.

Alternatively, a GenServer call may be made directly: ``GenServer.call({:global, {:broker_requester, server_login}}, {:function_to_call, params})``. But this is not recommended.

### Asynchronous nature of the calls
As the dedicated server don't provide means to identify calls and corresponding responses, calls are totally and exclusively asynchronous, so you can't be waiting for an answer. All you can do is firing the method, and wait for pubsub message to be broadcasted (see ``Mppm.Broker.MethodResponse``).
Thus, a single call may trigger lots of reactions from the message subscribers. But as it will mostly update their state, it shouldn't be a problem. 

## ReceiverServer

This process is in charge of everything sent from the dedicated server. It parses and decodes XML-RPC messages then commute them to MethodCall and MethodResponse.

It is also the one in charge of opening a connection to the dedicated server as soon as the XML-RPC port is open. It then publishes the connection established message, mentioned in the RequesterServer section :
``Phoenix.PubSub.broadcast(Mppm.PubSub, "broker-status:"<>state.login, {:connection_established, socket})``

## MethodCall and MethodResponse

Both modules are essentially an access and handling library for XML-RPC Methods and Callbacks, respectively.

Their role is to handle dedicated server messages, before broadcasting them to the whole system through various pubsub topics.

### MethodResponse

When calls are made by the RequesterServer, that's where you're expecting the dedicated server response to be handled.
The trick is that dedicated server don't provide way to know what's a response to what call. Once decoded, all we're left is with a map such as ``%{"Login" => login, "NickName" => nickname, "SpectatorStatus" => is_spectator?}`` for a ``GetPlayerInfo`` call.